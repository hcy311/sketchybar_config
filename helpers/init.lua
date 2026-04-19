-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

local config_dir = SKETCHYBAR_CONFIG_DIR or os.getenv("CONFIG_DIR") or "."
os.execute('cd "' .. config_dir .. '/helpers" && make')
