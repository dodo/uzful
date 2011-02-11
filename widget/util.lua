--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local Wibox = require("wibox")
local pairs = pairs


module("uzful.widget.util")


--- wibox helper
-- Just a wrapper for a nicer interface for `wibox`
-- @param args any wibox args plus screen, visible and widget
-- @param args.screen when given `wibox.screen` will be set
-- @param args.visible when given `wibox.visible` will be set
-- @param args.widget when given `wibox:set_widget` will be invoked
-- @return wibox object
function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    if args.widget then
        w:set_widget(args.widget)
    end
    return w
end

--- widget property setter
-- Any given property will invoke `widget:set_[property_key]([property_value])`.
-- @param widget the widget to be filled with properties
-- @param properties a table with the properties
-- @return the given widget
function set_properties(widget, properties)
    local fun = nil
    for name, property in pairs(properties) do
        fun = widget["set_" .. name]
        if fun then
            fun(widget, property)
        end
    end
    return widget
end