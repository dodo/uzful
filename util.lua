

local Wibox = require("wibox")

module("uzful.util")

function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    return w
end

patch = {
    vicious = function (vicious)
        local cache = {}
        local register = vicious.register
        vicious.register = function (widget, wtype, format, interval, warg)
            if cache[wtype] == nil then
                cache[wtype] = 1
                vicious.cache(wtype)
            end
            register(widget, wtype, format, interval, warg)
        end
    end,
    }

