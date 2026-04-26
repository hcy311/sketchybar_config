local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}
local total_spaces = 10
local floating_chat_apps = {
  WeChat = true,
  QQ = true,
}
local floating_chat_cache = {}

local function icon_for_app(app)
  local lookup = app_icons[app]
  return lookup == nil and app_icons["Default"] or lookup
end

local function set_space_icons(space_index, apps)
  local space = spaces[space_index]
  if not space then
    return
  end

  local icon_line = ""
  for _, app in ipairs(apps) do
    icon_line = icon_line .. icon_for_app(app)
  end

  if icon_line == "" then
    icon_line = " —"
  end

  sbar.animate("tanh", 10, function()
    space:set({ label = icon_line })
  end)
end

local function refresh_space_icons()
  local command = [[
current_space="$(yabai -m query --spaces 2>/dev/null | jq -r '.[] | select(."has-focus" == true) | .index' | head -n 1)"
printf '__CURRENT__\t%s\n' "${current_space:-0}"
yabai -m query --windows 2>/dev/null | jq -r '
  map(select(
    (.app // "") != "" and
    (.space // 0) > 0 and
    ((."is-minimized" // false) | not) and
    ((."is-hidden" // false) | not) and
    ((.role // "") == "AXWindow") and
    ((.subrole // "") == "AXStandardWindow")
  ))[] |
  "\(.space)\t\(.app // "")\t\((."is-floating" // false) | tostring)\t\((."is-visible" // false) | tostring)"
']]

  sbar.exec(command, function(output)
    local apps_by_space = {}
    local current_space = 0
    local space_app_state = {}

    for line in output:gmatch("[^\r\n]+") do
      local focused_space = line:match("^__CURRENT__\t(%d+)$")
      if focused_space then
        current_space = tonumber(focused_space) or 0
      else
        local space_id, app, is_floating, is_visible = line:match("^(%d+)\t([^\t]*)\t([^\t]+)\t([^\t]+)$")
        if space_id and app and app ~= "" then
          local index = tonumber(space_id)
          local state = space_app_state[index] or {}
          space_app_state[index] = state

          local app_state = state[app] or {
            visible = false,
            normal = false,
          }
          state[app] = app_state

          if is_floating == "true" then
            if is_visible == "true" then
              app_state.visible = true
            end
          else
            app_state.normal = true
          end
        end
      end
    end

    for i = 1, total_spaces do
      local state = space_app_state[i] or {}
      local apps = {}
      local cache = floating_chat_cache[i] or {}
      floating_chat_cache[i] = cache

      for app, app_state in pairs(state) do
        if app_state.normal then
          table.insert(apps, app)
        elseif floating_chat_apps[app] then
          if app_state.visible then
            cache[app] = true
            table.insert(apps, app)
          elseif current_space == i then
            cache[app] = nil
          elseif cache[app] then
            table.insert(apps, app)
          end
        elseif app_state.visible then
          table.insert(apps, app)
        end
      end

      if current_space == i then
        for app, _ in pairs(cache) do
          if not state[app] or not state[app].visible then
            cache[app] = nil
          end
        end
      end

      table.sort(apps)
      apps_by_space[i] = apps
    end

    for i = 1, total_spaces, 1 do
      set_space_icons(i, apps_by_space[i] or {})
    end
  end)
end

for i = 1, total_spaces, 1 do
  local space = sbar.add("space", "space." .. i, {
    space = i,
    icon = {
      font = { family = settings.font.numbers },
      string = i,
      padding_left = 15,
      padding_right = 8,
      color = colors.white,
      highlight_color = colors.red,
    },
    label = {
      padding_right = 20,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = -1,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 26,
      border_color = colors.black,
    },
    popup = { background = { border_width = 5, border_color = colors.black } }
  })

  spaces[i] = space

  -- Single item bracket for space items to achieve double border on highlight
  local space_bracket = sbar.add("bracket", { space.name }, {
    background = {
      color = colors.transparent,
      border_color = colors.bg2,
      height = 28,
      border_width = 2
    }
  })

  -- Padding space
  sbar.add("space", "space.padding." .. i, {
    space = i,
    script = "",
    width = settings.group_paddings,
  })

  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left= 5,
    padding_right= 0,
    background = {
      drawing = true,
      image = {
        corner_radius = 9,
        scale = 0.2
      }
    }
  })

  space:subscribe("space_change", function(env)
    local selected = env.SELECTED == "true"
    local color = selected and colors.grey or colors.bg2
    space:set({
      icon = { highlight = selected, },
      label = { highlight = selected },
      background = { border_color = selected and colors.black or colors.bg2 }
    })
    space_bracket:set({
      background = { border_color = selected and colors.grey or colors.bg2 }
    })
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "other" then
      space_popup:set({ background = { image = "space." .. env.SID } })
      space:set({ popup = { drawing = "toggle" } })
    else
      local op = (env.BUTTON == "right") and "--destroy" or "--focus"
      sbar.exec("yabai -m space " .. op .. " " .. env.SID)
    end
  end)

  space:subscribe("mouse.exited", function(_)
    space:set({ popup = { drawing = false } })
  end)
end

local space_window_observer = sbar.add("item", {
  drawing = false,
  updates = true,
})

local spaces_indicator = sbar.add("item", {
  padding_left = -3,
  padding_right = 0,
  icon = {
    padding_left = 8,
    padding_right = 9,
    color = colors.grey,
    string = icons.switch.on,
  },
  label = {
    width = 0,
    padding_left = 0,
    padding_right = 8,
    string = "Spaces",
    color = colors.bg1,
  },
  background = {
    color = colors.with_alpha(colors.grey, 0.0),
    border_color = colors.with_alpha(colors.bg1, 0.0),
  }
})

space_window_observer:subscribe({ "space_windows_change", "space_change", "system_woke", "forced" }, refresh_space_icons)

refresh_space_icons()

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
  local currently_on = spaces_indicator:query().icon.value == icons.switch.on
  spaces_indicator:set({
    icon = currently_on and icons.switch.off or icons.switch.on
  })
end)

spaces_indicator:subscribe("mouse.entered", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 1.0 },
        border_color = { alpha = 1.0 },
      },
      icon = { color = colors.bg1 },
      label = { width = "dynamic" }
    })
  end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 0.0 },
        border_color = { alpha = 0.0 },
      },
      icon = { color = colors.grey },
      label = { width = 0, }
    })
  end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
