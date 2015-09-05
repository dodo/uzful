--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local widget = require("uzful.notifications.widget")
local phone = require("uzful.notifications.phone")
local util = require("uzful.notifications.util")

return setmetatable({
    patch = widget.patch,
    critical = util.critical,
    debug = util.debug,
    widget = widget,
    phone = phone,
    util = util,
}, { __call = function (_, ...) return widget(...) end })
