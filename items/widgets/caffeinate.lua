local colors = require("colors")

local caffeine = sbar.add("item", "widgets.caffeine", {
  position = "right",
  update_freq = 10,
  icon = {
    string = "􀸙",
    padding_left = 10,
    padding_right = 10,
    color = colors.grey,
  },
  label = { drawing = false },
  background = {
    color = colors.bg1,
    corner_radius = 9,
    height = 28,
  },
})

local function refresh()
  sbar.exec("pgrep -f 'caffeinate -dimsu' >/dev/null && echo on || echo off", function(state)
    local active = state:gsub("%s+", "") == "on"

    caffeine:set({
      icon = { color = active and colors.yellow or colors.grey },
    })
  end)
end

caffeine:subscribe({ "forced", "routine", "system_woke" }, refresh)

caffeine:subscribe("mouse.clicked", function()
  sbar.exec("if pgrep -f 'caffeinate -dimsu' >/dev/null; then pkill -f 'caffeinate -dimsu'; else nohup caffeinate -dimsu >/dev/null 2>&1 & fi", refresh)
end)

sbar.add("item", "widgets.caffeine.padding", {
  position = "right",
  width = 5,
})

refresh()
