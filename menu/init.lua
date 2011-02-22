--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------


require("uzful.menu.util")
require("uzful.menu.popup")

local setmetatable = setmetatable
local util = require("uzful.menu.util")
local popup = require("uzful.menu.popup")


module("uzful.menu")


toggle_widgets = util.toggle_widgets
layouts = util.layouts

setmetatable(_M, { __call = function (_, ...) return popup.new(...) end })

