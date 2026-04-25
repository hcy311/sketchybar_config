local icons = require("icons")
local colors = require("colors")
local config_dir = SKETCHYBAR_CONFIG_DIR or os.getenv("CONFIG_DIR") or "."

local whitelist = {
  ["Spotify"] = true,
  ["Music"] = true,
  ["音乐"] = true,
}

sbar.exec("killall media_change >/dev/null")

local media_cover = sbar.add("item", {
  position = "right",
  update_freq = 0,
  background = {
    image = {
      string = "media.artwork",
      scale = 0.85,
    },
    color = colors.transparent,
  },
  label = { drawing = false },
  icon = { drawing = false },
  drawing = false,
  updates = true,
  popup = {
    align = "center",
    horizontal = true,
  }
})

local media_artist = sbar.add("item", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  width = 0,
  icon = { drawing = false },
  label = {
    width = 0,
    font = { size = 9 },
    color = colors.with_alpha(colors.white, 0.6),
    max_chars = 18,
    y_offset = 6,
  },
})

local media_title = sbar.add("item", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = { size = 11 },
    width = 0,
    max_chars = 16,
    y_offset = -5,
  },
})

sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.back },
  label = { drawing = false },
  click_script = "nowplaying-cli previous",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.play_pause },
  label = { drawing = false },
  click_script = "nowplaying-cli togglePlayPause",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.forward },
  label = { drawing = false },
  click_script = "nowplaying-cli next",
})

local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

local function is_supported_app(app)
  if not app or app == "" then return false end
  if whitelist[app] then return true end

  local normalized = string.lower(app)
  return normalized:find("music", 1, true) ~= nil
    or normalized:find("spotify", 1, true) ~= nil
end

local function is_playing_state(state)
  if not state or state == "" then return false end
  return string.lower(state):find("playing", 1, true) ~= nil
end

local function apply_media(app, state, title, artist)
  local drawing = is_supported_app(app) and is_playing_state(state)

  media_artist:set({
    drawing = drawing,
    label = artist or "",
  })

  media_title:set({
    drawing = drawing,
    label = title or "",
  })

  media_cover:set({ drawing = drawing })

  if drawing then
    animate_detail(true)
    interrupt = interrupt + 1
    sbar.delay(5, animate_detail)
  else
    media_cover:set({ popup = { drawing = false } })
  end
end

local function refresh_media()
  sbar.exec(config_dir .. "/scripts/nowplaying_media.sh", function(output)
    output = (output or ""):gsub("%s+$", "")

    local app, state, title, artist = output:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if not app then
      apply_media("", "stopped", "", "")
      return
    end

    apply_media(app, state, title, artist)
  end)
end

media_cover:subscribe({ "routine", "system_woke", "forced" }, refresh_media)

media_cover:subscribe("mouse.entered", function(_)
  interrupt = interrupt + 1
  animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(_)
  animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(_)
  media_cover:set({ popup = { drawing = "toggle" }})
end)

media_title:subscribe("mouse.exited.global", function(_)
  media_cover:set({ popup = { drawing = false }})
end)
