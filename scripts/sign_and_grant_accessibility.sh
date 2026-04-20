#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${IDENTITY_NAME:-Local SketchyBar Code Signing 2}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
BREW_BIN="${BREW_BIN:-/opt/homebrew/bin/sketchybar}"
OPT_BIN="${OPT_BIN:-/opt/homebrew/opt/sketchybar/bin/sketchybar}"
PLIST="$HOME/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist"
SERVICE="homebrew.mxcl.sketchybar"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
CERT_PREFIX="/tmp/sketchybar_codesign"
REQ_FILE="/tmp/sketchybar_current.req"
CSREQ_FILE="/tmp/sketchybar_current.csreq"
ADMIN_SCRIPT="/tmp/grant_sketchybar_accessibility.sh"
USER_ID="$(id -u)"

if [ ! -x "$BREW_BIN" ]; then
  echo "SketchyBar binary not found at $BREW_BIN" >&2
  exit 1
fi

REAL_BIN="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$BREW_BIN")"

create_identity_if_missing() {
  if security find-identity -v -p codesigning | grep -F "\"$IDENTITY_NAME\"" >/dev/null 2>&1; then
    return
  fi

  echo "Creating local Code Signing identity: $IDENTITY_NAME"
  openssl req -new -newkey rsa:2048 -nodes -x509 -days 3650 \
    -subj "/CN=$IDENTITY_NAME/" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$CERT_PREFIX.key" \
    -out "$CERT_PREFIX.crt"

  openssl pkcs12 -legacy -export \
    -inkey "$CERT_PREFIX.key" \
    -in "$CERT_PREFIX.crt" \
    -name "$IDENTITY_NAME" \
    -out "$CERT_PREFIX.p12" \
    -passout pass:sketchybar

  security import "$CERT_PREFIX.p12" \
    -k "$KEYCHAIN" \
    -P sketchybar \
    -T /usr/bin/codesign

  osascript -e "do shell script \"security add-trusted-cert -d -r trustRoot -p codeSign -k '$KEYCHAIN' '$CERT_PREFIX.crt'\" with administrator privileges"
}

sign_binary() {
  launchctl bootout "gui/$USER_ID/$SERVICE" 2>/dev/null || true

  chmod u+w "$REAL_BIN" 2>/dev/null || true
  codesign --force --sign "$IDENTITY_NAME" \
    --identifier git.felix.sketchybar \
    "$REAL_BIN"
}

write_launchagent_path() {
  if [ -f "$PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $BREW_BIN" "$PLIST"
  else
    echo "LaunchAgent plist not found at $PLIST" >&2
    exit 1
  fi
}

build_csreq() {
  codesign -dr - "$REAL_BIN" 2>&1 | sed 's/^designated => //' > "$REQ_FILE"
  csreq -r "$REQ_FILE" -b "$CSREQ_FILE"
}

grant_accessibility() {
  cat > "$ADMIN_SCRIPT" <<SCRIPT
#!/bin/zsh
set -euo pipefail

DB="/Library/Application Support/com.apple.TCC/TCC.db"
CSREQ="$CSREQ_FILE"

sqlite3 "\$DB" <<SQL
insert or replace into access (
  service,
  client,
  client_type,
  auth_value,
  auth_reason,
  auth_version,
  csreq,
  policy_id,
  indirect_object_identifier_type,
  indirect_object_identifier,
  indirect_object_code_identity,
  flags,
  last_modified,
  pid,
  pid_version,
  boot_uuid,
  last_reminded
) values
('kTCCServiceAccessibility', '$REAL_BIN', 1, 2, 4, 1, readfile('\$CSREQ'), null, null, 'UNUSED', null, 0, strftime('%s','now'), null, null, 'UNUSED', strftime('%s','now')),
('kTCCServiceAccessibility', '$BREW_BIN', 1, 2, 4, 1, readfile('\$CSREQ'), null, null, 'UNUSED', null, 0, strftime('%s','now'), null, null, 'UNUSED', strftime('%s','now')),
('kTCCServiceAccessibility', '$OPT_BIN', 1, 2, 4, 1, readfile('\$CSREQ'), null, null, 'UNUSED', null, 0, strftime('%s','now'), null, null, 'UNUSED', strftime('%s','now'));
SQL

killall tccd 2>/dev/null || true
SCRIPT

  chmod +x "$ADMIN_SCRIPT"
  osascript -e "do shell script \"/bin/zsh '$ADMIN_SCRIPT'\" with administrator privileges"
}

restart_service() {
  launchctl bootstrap "gui/$USER_ID" "$PLIST" 2>/dev/null || true
  launchctl kickstart -k "gui/$USER_ID/$SERVICE"
}

verify() {
  echo
  echo "Signed identity:"
  codesign -dr - "$REAL_BIN" 2>&1

  echo
  echo "LaunchAgent target:"
  launchctl print "gui/$USER_ID/$SERVICE" | sed -n '1,20p'

  echo
  echo "Accessibility rows:"
  sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    "select client, auth_value, auth_reason, length(csreq) from access where service='kTCCServiceAccessibility' and client like '%sketchybar%' order by client;" \
    2>/dev/null || true
}

create_identity_if_missing
sign_binary
write_launchagent_path
build_csreq
grant_accessibility
restart_service
verify

echo
echo "SketchyBar was signed, granted Accessibility in system TCC.db, and restarted."
