--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local widget = require("uzful.notifications.widget")

return setmetatable({
    patch = widget.patch,
    widget = widget,
}, { __call = function (_, ...) return widget(...) end })
