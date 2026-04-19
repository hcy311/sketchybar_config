local function system_appearance()
  local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if not handle then
    return "light"
  end

  local result = handle:read("*a") or ""
  handle:close()

  return result:match("Dark") and "dark" or "light"
end

local appearance = system_appearance()
local dark = appearance == "dark"

local palette = {
  red = dark and 0xfffc5d7c or 0xffb3261e,
  green = dark and 0xff9ed072 or 0xff2e7d32,
  blue = dark and 0xff76cce0 or 0xff006a6a,
  yellow = dark and 0xffe7c664 or 0xff8b6f00,
  orange = dark and 0xfff39660 or 0xffa14000,
  magenta = dark and 0xffb39df3 or 0xff6750a4,
}

local colors = {
  appearance = appearance,
  is_dark = dark,

  -- Semantic foreground/background names retained for existing item configs.
  white = dark and 0xfff2edea or 0xff1d1b20,
  black = dark and 0xff181819 or 0xfffffbff,
  grey = dark and 0xffc8c2bd or 0xff625b71,
  transparent = 0x00000000,

  red = palette.red,
  green = palette.green,
  blue = palette.blue,
  yellow = palette.yellow,
  orange = palette.orange,
  magenta = palette.magenta,

  bar = {
    bg = dark and 0x8A3B302F or 0x8AF6EEE7,
    border = dark and 0xff2c2e34 or 0xffded8e1,
  },
  item = {
    bg = dark and 0xCC2F2828 or 0xDDFDF7F2,
    bg_hover = dark and 0xE03A3333 or 0xEEF8F0EA,
    border = dark and 0x88f2edea or 0x881d1b20,
  },
  popup = {
    bg = dark and 0xd02c2e34 or 0xeefef7ff,
    border = dark and 0xff7f8490 or 0xffcac4d0
  },
  bg1 = dark and 0xCC2F2828 or 0xDDFDF7F2,
  bg2 = dark and 0xD63A3333 or 0xEEE9E0D9,
}

colors.with_alpha = function(color, alpha)
  if alpha > 1.0 or alpha < 0.0 then return color end
  return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

return colors
