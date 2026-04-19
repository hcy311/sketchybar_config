local colors = require("colors")
local settings = require("settings")

local caffeine = sbar.add("item", "widgets.caffeine", {
  position = "right",
  update_freq = 10,
  icon = {
    string = "􀸙",
    padding_left = 9,
    padding_right = 6,
    color = colors.grey,
  },
  label = {
    string = "Sleep",
    padding_right = 9,
    color = colors.grey,
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Semibold"],
      size = 12.0,
    },
  },
  background = {
    color = colors.bg1,
  },
})

local function refresh()
  sbar.exec("pgrep -f 'caffeinate -dimsu' >/dev/null && echo on || echo off", function(state)
    local active = state:gsub("%s+", "") == "on"

    caffeine:set({
      icon = { color = active and colors.yellow or colors.grey },
      label = {
        string = active and "Awake" or "Sleep",
        color = active and colors.white or colors.grey,
      },
    })
  end)
end

caffeine:subscribe({ "forced", "routine", "system_woke" }, refresh)

caffeine:subscribe("mouse.clicked", function()
  sbar.exec("if pgrep -f 'caffeinate -dimsu' >/dev/null; then pkill -f 'caffeinate -dimsu'; else nohup caffeinate -dimsu >/dev/null 2>&1 & fi", refresh)
end)

sbar.add("bracket", "widgets.caffeine.bracket", { caffeine.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.caffeine.padding", {
  position = "right",
  width = settings.group_paddings,
})

refresh()
