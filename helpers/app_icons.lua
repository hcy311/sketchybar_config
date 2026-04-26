local base = require("helpers.app_icons_base")
local overrides = require("helpers.app_icons_overrides")

for app_name, icon in pairs(overrides) do
  base[app_name] = icon
end

return base
