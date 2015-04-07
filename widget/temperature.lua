  --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local temperature = { mt = {} }

local _, vicious = pcall(require, "vicious")
local beautiful = require("beautiful")
local capi = { dbus = dbus }
local uzful = {
    util = require("uzful.util"),
    widget = { set_properties = require("uzful.widget.util").set_properties },
}

-- uzful.widget.temperature({
--     width = 161, height = 42,
--     font = "sans 6",
-- })
local function new(args)
    args = args or {}
    args.normal = args.normal or "#666666"
    args.critical = args.critical or "red"
    args.label = args.label or {}
    args.label.normal = args.label.normal or '<span color="%s" size="small">%d°</span>'
    args.label.critical = args.label.critical or '<span color="%s">%d°</span>'
    local ret = {}
    ret.text = wibox.widget.textbox()
    if args.font then ret.text:set_font(args.font) end
    if args.notifications ~= false then
        ret.notifications = uzful.util.threshold(args.threshold or 0.8,
            function (val)
                ret.text:set_markup(string.format(
                    args.label.critical, args.critical, val*100))
            end,
            function (val)
                ret.text:set_markup(string.format(
                    args.label.normal, args.normal, val*100))
            end)
    end
    if args.graph ~= false then
        ret.graph = awful.widget.graph({
            width = args.width, height = args.height })
        uzful.widget.set_properties(ret.graph, {
            border_color = nil,
            color = args.color or "#AA0000",
            background_color = args.bgcolor or "#000000" })
    end
    return ret
end


function temperature.mt:__call(...)
    return new(...)
end

return setmetatable(temperature, temperature.mt)
