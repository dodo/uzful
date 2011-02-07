

local awful = require("awful")

module("uzful.util")

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

function change_volume(delta)
    awful.util.spawn("amixer -q set Master " .. delta)
end

