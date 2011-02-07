--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local awful = require("awful")

module("uzful.util")

patch = {
    --- Enables always vicious.cache for all registered vicious widgets
    -- It overrides `vicious.register`.
    -- @param vicious The required vicious library
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

--- Change system volume
-- use it like this for example:
-- <code>
-- awful.key({ modkey            }, "<",      function () uzful.util.change_volume("1%-") end),
-- awful.key({ modkey, "Shift"   }, "<",      function () uzful.util.change_volume("1%+") end),
-- </code>
-- thanks to <a href="https://github.com/twobit">twobit</a>.
-- @param delta The volume delta to change in percentage (e.g. "1%+")
function change_volume(delta)
    awful.util.spawn("amixer -q set Master " .. delta)
end

