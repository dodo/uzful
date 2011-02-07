
local Wibox = require("wibox")
local pairs = pairs
local print = print

module("uzful.widget")

function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    return w
end

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

