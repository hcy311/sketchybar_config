local colors = require("colors")
local settings = require("settings")

local current_app_name = nil

local front_app = sbar.add("item", "front_app", {
  display = "active",
  icon = {
    drawing = false,
    width = 0,
    padding_left = 0,
    padding_right = 0,
  },
  label = {
    padding_left = 0,
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0,
    },
  },
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  local app_name = (env.INFO or ""):gsub("%s+$", "")

  if app_name == "" or app_name == current_app_name then
    return
  end

  current_app_name = app_name
  front_app:set({ label = { string = app_name } })
end)

front_app:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
