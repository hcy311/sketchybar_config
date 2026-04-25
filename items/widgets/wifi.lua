local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local config_dir = SKETCHYBAR_CONFIG_DIR or os.getenv("CONFIG_DIR") or "."

-- Execute the event provider binary which provides the event "network_update"
-- for the network interface "en0", which is fired every 2.0 seconds.
sbar.exec("killall network_load >/dev/null; " .. config_dir .. "/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0")

local popup_width = 250
local connectivity_type = "off"
local proxy_state = "off"
local proxy_app_name = "None"
local notified_proxy_key = nil

local proxy_detectors = {
  {
    name = "Loon",
    scutil_match = "com.ruikq.decar|com.loon.Loon|Loon",
    process = "pgrep -f 'LoonTunnelProvider' >/dev/null 2>&1 || pgrep -f 'com.loon.Loon.LoonHelper' >/dev/null 2>&1",
  },
  {
    name = "Shadowrocket",
    scutil_match = "Shadowrocket",
    process = "pgrep -f 'Shadowrocket' >/dev/null 2>&1",
  },
  {
    name = "Quantumult X",
    scutil_match = "Quantumult X",
    process = "pgrep -f 'Quantumult X' >/dev/null 2>&1 || pgrep -f 'QuantumultXHelper' >/dev/null 2>&1",
  },
  {
    name = "Clash Verge",
    scutil_match = "clash-verge|Clash Verge|io.github.clash-verge",
    process = "pgrep -f 'Clash Verge' >/dev/null 2>&1 || pgrep -f 'clash-verge' >/dev/null 2>&1 || pgrep -f 'ClashVerge' >/dev/null 2>&1 || pgrep -f 'clash-verge-service' >/dev/null 2>&1",
  },
}

local wifi_up = sbar.add("item", "widgets.wifi1", {
  position = "right",
  padding_left = -5,
  width = 0,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.upload,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.red,
    string = "??? Bps",
  },
  y_offset = 4,
})

local wifi_down = sbar.add("item", "widgets.wifi2", {
  position = "right",
  padding_left = -5,
  icon = {
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    string = icons.wifi.download,
  },
  label = {
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    color = colors.blue,
    string = "??? Bps",
  },
  y_offset = -4,
})

local wifi = sbar.add("item", "widgets.wifi.padding", {
  position = "right",
  label = { drawing = false },
})

local wifi_state_observer = sbar.add("item", "widgets.wifi.state_observer", {
  drawing = false,
  updates = true,
  update_freq = 2,
})

-- Background around the item
local wifi_bracket = sbar.add("bracket", "widgets.wifi.bracket", {
  wifi.name,
  wifi_up.name,
  wifi_down.name
}, {
  background = { color = colors.bg1 },
  popup = { align = "center", height = 30 }
})

local ssid = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    font = {
      style = settings.font.style_map["Bold"]
    },
    string = icons.wifi.router,
  },
  width = popup_width,
  align = "center",
  label = {
    font = {
      size = 15,
      style = settings.font.style_map["Bold"]
    },
    max_chars = 18,
    string = "????????????",
  },
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15
  }
})

local hostname = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Hostname:",
    width = popup_width / 2,
  },
  label = {
    max_chars = 20,
    string = "????????????",
    width = popup_width / 2,
    align = "right",
  }
})

local ip = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "IP:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  }
})

local mask = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Subnet mask:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  }
})

local router = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Router:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  },
})

local proxy = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Proxy:",
    width = popup_width / 2,
  },
  label = {
    string = "None",
    width = popup_width / 2,
    align = "right",
  },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

local function connectivity_probe_command()
  return [[
    if ipconfig getifaddr en0 >/dev/null 2>&1; then
      echo "wifi"
    elif ifconfig 2>/dev/null | awk '
      /^[a-z0-9]+: flags=/ { iface=$1; sub(":", "", iface) }
      /status: active/ { active[iface]=1 }
      /inet / && $2 != "127.0.0.1" { inet[iface]=1 }
      END {
        for (iface in active) {
          if (iface ~ /^en[1-9][0-9]*$/ && inet[iface]) {
            print "lan"
            exit
          }
        }
      }
    '; then
      :
    fi
  ]]
end

local function apply_wifi_icon_state()
  local icon_string = icons.wifi.disconnected
  local icon_color = colors.red

  if connectivity_type == "wifi" then
    icon_string = icons.wifi.connected
  elseif connectivity_type == "lan" then
    icon_string = icons.wifi.router
  end

  if connectivity_type ~= "off" then
    if proxy_state == "on" then
      icon_color = colors.green
    elseif proxy_state == "error" then
      icon_color = colors.orange
    else
      icon_color = colors.white
    end
  end

  wifi:set({
    icon = {
      string = icon_string,
      color = icon_color,
    },
  })
end

local function refresh_connectivity()
  sbar.exec(connectivity_probe_command(), function(state)
    state = (state or ""):gsub("%s+", "")
    if state ~= "wifi" and state ~= "lan" then
      state = "off"
    end

    connectivity_type = state
    apply_wifi_icon_state()
  end)
end

local function proxy_probe_command()
  local parts = {}
  for _, detector in ipairs(proxy_detectors) do
    local escaped_name = detector.name:gsub("'", [['"'"']])
    table.insert(parts, [[
      sc_line="$(scutil --nc list 2>/dev/null | egrep -i ']] .. detector.scutil_match .. [[' | head -n 1)"
      if [ -n "$sc_line" ]; then
        utun_up=0
        if ifconfig 2>/dev/null | awk '
          /^[a-z0-9]+: flags=/ { iface=$1; sub(":", "", iface) }
          /^utun[0-9]+:/ { current=iface }
          current ~ /^utun[0-9]+$/ && /inet / { found=1 }
          END { exit(found ? 0 : 1) }
        '; then
          utun_up=1
        fi

        if printf '%s' "$sc_line" | grep -q '(Connected)'; then
          if [ "$utun_up" -eq 1 ]; then
            if ]] .. detector.process .. [[; then
              echo ']] .. escaped_name .. [[	on'
            else
              echo ']] .. escaped_name .. [[	error'
            fi
          else
            echo ']] .. escaped_name .. [[	off'
          fi
        elif [ "$utun_up" -eq 0 ]; then
          echo ']] .. escaped_name .. [[	off'
        else
          echo ']] .. escaped_name .. [[	off'
        fi
        exit 0
      fi

      if ]] .. detector.process .. [[; then
        echo ']] .. escaped_name .. [[	off'
        exit 0
      fi
    ]])
  end

  return table.concat(parts, "\n") .. "\necho 'None\toff'\n"
end

wifi_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.red
  local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
  wifi_up:set({
    icon = { color = up_color },
    label = {
      string = env.upload,
      color = up_color
    }
  })
  wifi_down:set({
    icon = { color = down_color },
    label = {
      string = env.download,
      color = down_color
    }
  })
end)

wifi:subscribe({"wifi_change", "system_woke"}, function(env)
  refresh_connectivity()
end)

local function notify_proxy_state_change(app_name, state)
  local key = app_name .. ":" .. state
  if notified_proxy_key == nil then
    notified_proxy_key = key
    return
  end

  if key == notified_proxy_key then
    return
  end

  local title = app_name == "None" and "Proxy" or app_name
  local body = nil

  if state == "on" then
    body = "Proxy connected"
  elseif state == "error" then
    body = "VPN is connected but proxy helper/tunnel is missing"
  elseif state == "off" then
    body = app_name == "None" and "No supported proxy detected" or "Proxy disconnected"
  end

  notified_proxy_key = key

  if body then
    sbar.exec("osascript -e " .. string.format("%q", 'display notification "' .. body .. '" with title "' .. title .. '"'))
  end
end

local function refresh_proxy_state()
  local command = proxy_probe_command()
  sbar.exec(command, function(state)
    state = (state or ""):gsub("%s+$", "")
    local app_name, status = state:match("^([^\t]+)\t([^\t]+)$")
    if not app_name then
      app_name = "None"
      status = "off"
    end

    proxy_app_name = app_name
    proxy_state = status
    apply_wifi_icon_state()
    notify_proxy_state_change(proxy_app_name, proxy_state)
  end)
end

local function hide_details()
  wifi_bracket:set({ popup = { drawing = false } })
end

local function toggle_details()
  local should_draw = wifi_bracket:query().popup.drawing == "off"
  if should_draw then
    wifi_bracket:set({ popup = { drawing = true }})
    sbar.exec("networksetup -getcomputername", function(result)
      hostname:set({ label = result })
    end)
    sbar.exec("ipconfig getifaddr en0", function(result)
      result = (result or ""):gsub("%s+$", "")
      if result == "" then
        result = "Unavailable"
      end
      ip:set({ label = result })
    end)
    sbar.exec(connectivity_probe_command(), function(result)
      result = (result or ""):gsub("%s+", "")
      local summary = "Offline"
      if result == "wifi" then
        summary = "Wi-Fi Link"
      elseif result == "lan" then
        summary = "LAN Link"
      end
      ssid:set({ label = summary })
    end)
    sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'", function(result)
      mask:set({ label = result })
    end)
    sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'", function(result)
      router:set({ label = result })
    end)
    proxy:set({
      label = {
        string = proxy_app_name == "None" and "None" or (proxy_app_name .. " " .. proxy_state),
      },
    })
  else
    hide_details()
  end
end

wifi_up:subscribe("mouse.clicked", toggle_details)
wifi_down:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.exited.global", hide_details)
wifi_state_observer:subscribe({ "forced", "routine", "system_woke" }, function()
  refresh_connectivity()
  refresh_proxy_state()
end)

local function copy_label_to_clipboard(env)
  local label = sbar.query(env.NAME).label.value
  sbar.exec("echo \"" .. label .. "\" | pbcopy")
  sbar.set(env.NAME, { label = { string = icons.clipboard, align="center" } })
  sbar.delay(1, function()
    sbar.set(env.NAME, { label = { string = label, align = "right" } })
  end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
proxy:subscribe("mouse.clicked", copy_label_to_clipboard)

refresh_proxy_state()
refresh_connectivity()
apply_wifi_icon_state()
