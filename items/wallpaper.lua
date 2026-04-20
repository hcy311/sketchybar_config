local config_dir = SKETCHYBAR_CONFIG_DIR or os.getenv("CONFIG_DIR") or "."

local wallpaper = sbar.add("item", "wallpaper.color", {
  drawing = false,
  updates = false,
})

local function update_bar_color()
  local helper = config_dir .. "/scripts/wallpaper_color"
  local source = config_dir .. "/scripts/wallpaper_color.swift"
  local wallpaper_path = "wallpaper_path=$(osascript -e 'tell application \"System Events\" to get picture of current desktop' 2>/dev/null); "
  local command = wallpaper_path
    .. "if [ -x " .. string.format("%q", helper) .. " ]; then "
    .. string.format("%q", helper) .. " \"$wallpaper_path\"; else "
    .. "/usr/bin/swift -module-cache-path /tmp/sketchybar-swift-cache "
    .. string.format("%q", source) .. " \"$wallpaper_path\"; fi"

  sbar.exec(command, function(color)
    color = color:gsub("%s+", "")

    if color:match("^0x%x%x%x%x%x%x%x%x$") then
      sbar.animate("tanh", 20, function()
        sbar.bar({ color = color })
      end)
    end
  end)
end

wallpaper:subscribe("forced", update_bar_color)
update_bar_color()
