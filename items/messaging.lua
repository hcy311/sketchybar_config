local colors = require("colors")
local settings = require("settings")

local items = {}
local messaging_bracket
local messaging_padding

local function badge_command(app_names)
  local pattern = table.concat(app_names, "\\|")
  return "line=$(lsappinfo -all list | grep -m 1 " .. string.format("%q", pattern) .. "); "
    .. "if [ -z \"$line\" ]; then echo __NOT_RUNNING__; exit 0; fi; "
    .. "printf '%s\\n' \"$line\""
    .. " | egrep -o '\"StatusLabel\"=\\{ \"label\"=\"?(.*?)\"? \\}'"
    .. " | sed 's/\"StatusLabel\"={ \"label\"=\\(.*\\) }/\\1/g'"
    .. " | sed 's/^\"//; s/\"$//'"
end

local function update_group_visibility()
  local any_running = false

  for _, item in ipairs(items) do
    if item.running then
      any_running = true
      break
    end
  end

  if messaging_bracket then
    messaging_bracket:set({ drawing = any_running })
  end

  if messaging_padding then
    messaging_padding:set({ drawing = any_running })
  end
end

local function add_badge_item(name, app_names, icon, icon_size, click_app)
  local item = sbar.add("item", name, {
    position = "right",
    drawing = false,
    updates = true,
    update_freq = 1,
    icon = {
      string = icon,
      font = {
        family = "Hack Nerd Font",
        style = "Regular",
        size = icon_size,
      },
      padding_left = 7,
      padding_right = 2,
      color = colors.white,
    },
    label = {
      string = "-",
      width = 18,
      align = "left",
      padding_left = 0,
      padding_right = 5,
      font = { family = settings.font.numbers },
      color = colors.white,
    },
    click_script = "open -a " .. string.format("%q", click_app),
  })

  item.running = false
  table.insert(items, item)

  item:subscribe({ "forced", "routine", "system_woke" }, function()
    sbar.exec(badge_command(app_names), function(label)
      label = label:gsub("%s+$", "")

      if label == "__NOT_RUNNING__" then
        item.running = false
        item:set({ drawing = false })
        update_group_visibility()
        return
      end

      if label == "" then
        label = "0"
      end

      item.running = true
      item:set({
        drawing = true,
        label = { string = label },
      })
      update_group_visibility()
    end)
  end)

  return item
end

local qq = add_badge_item("qq", { "QQ" }, "󰘅", 19.0, "QQ")
local wechat = add_badge_item("wechat", { "WeChat", "微信" }, "󰘑", 20.0, "WeChat")
local whatsapp = add_badge_item("whatsapp", { "WhatsApp", "WhatsApp Beta" }, "", 18.0, "WhatsApp")

messaging_bracket = sbar.add("bracket", "messaging", { qq.name, wechat.name, whatsapp.name }, {
  drawing = false,
  background = {
    color = colors.bg1,
    border_color = colors.transparent,
  }
})

messaging_padding = sbar.add("item", "messaging.padding", {
  position = "right",
  drawing = false,
  width = settings.group_paddings,
})
