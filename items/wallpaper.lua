local config_dir = SKETCHYBAR_CONFIG_DIR or os.getenv("CONFIG_DIR") or "."

local wallpaper = sbar.add("item", "wallpaper.color", {
  drawing = false,
  updates = false,
})

local function update_bar_color()
  local command = "if [ -x " .. config_dir .. "/scripts/wallpaper_color ]; then "
    .. config_dir .. "/scripts/wallpaper_color; else "
    .. "/usr/bin/swift -module-cache-path /tmp/sketchybar-swift-cache "
    .. config_dir .. "/scripts/wallpaper_color.swift; fi"

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
