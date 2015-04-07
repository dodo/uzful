 --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local wicd = { mt = {} }

-- constants
wicd.BUS = 'system'
wicd.PATH = '/org/wicd/daemon'
wicd.INTERFACE = 'org.wicd.daemon'


local _, luadbus = pcall(require, "lua-dbus")
local beautiful = require("beautiful")
local capi = { dbus = dbus }
local uzful = {
    widget = {
        progressimage = require("uzful.widget.progressimage"),
        set_properties = require("uzful.widget.util").set_properties,
    },
}

-- uzful.widget.wicd({
--     x = 1, y = 2, width = 3, height = 9,
--     theme = theme.wicd, font = "ProggyTinyTT 7",
--     onupdate = function () … end,
--     onconnect = function (kind) … end,
-- })
local function new(args)
    args = args or {}
    args.theme = args.theme or beautiful.get()
    args.color = args.color or "#33FF3399"
    args.bgcolor = args.bgcolor or "#000000"
    local ret = {}
    ret.widget = uzful.widget.progressimage({
        image = args.theme.unknown,
        draw_image_first = false,
        x = args.x, y = args.y, width = args.width, height = args.height })
    uzful.widget.set_properties(ret.widget.progress, {
        ticks = true, ticks_gap = 1,  ticks_size = 1,
        vertical = true, background_color = args.bgcolor,
        border_color = nil, color = args.color })
    if args.text ~= false then
        ret.text = wibox.widget.textbox()
        if args.font then ret.text:set_font(args.font) end
        ret.text:set_text(" ")
    end
    local connecting = false
    ret.change = function (status, data)
        local state = ({
            "not_connected","connecting","wireless","wired","suspended"
        })[status + 1] or "unknown"
--         print("changed wicd status to "..state)
        ret.widget:set_image(args.theme[state])
        if connecting and (state == "wireless" or state == "wired") then
            connecting = false
            if args.onupdate then args.onupdate() end
        end
        if state == "wireless" then
            ret.widget.progress:set_value((data[3] or 0) / 100)
        else
            if state == "connecting" then
                connecting = true
                if args.onconnect then args.onconnect(data[1]) end
            end
            ret.widget.progress:set_value(nil)
            if state == "not_connected" or state == "suspended" then
            if args.ondisconnect then args.ondisconnect() end
            end
        end
        if ret.text then
            local text = ""
            for _, line in ipairs(data) do text = text .. line .. "\n" end
            if text == "" or text == "\n" then text = " " end
            ret.text:set_text(text)
        end
    end
    luadbus.on('StatusChanged', ret.change, { bus = wicd.BUS, interface = wicd.INTERFACE })
    -- get initial state
    luadbus.call('GetConnectionStatus', function (args)
        ret.change(unpack(args))
    end, {
        destination = wicd.INTERFACE,
        interface = wicd.INTERFACE,
        path = wicd.PATH,
        bus = wicd.BUS,
    })
    return ret
end


function wicd.mt:__call(...)
    return new(...)
end

return setmetatable(wicd, wicd.mt)
