--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local obvious = {}
local require = require

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
-- uses <b>obvious</b>
-- use it like this for example:
-- <code>
-- volume = uzful.util.volume("Master")<br/>
-- awful.key({ modkey            }, "<",      function () volume.lower() end),<br/>
-- awful.key({ modkey, "Shift"   }, "<",      function () volume.raise() end),<br/>
-- </code>
-- @param channel the audio channel you want control
-- @param typ <i>(default: "alsa")</i> obvious has to modules for volume control: alsa and freebsd
-- @param cardid <i>(optional when typ == "alsa", default: 0)</i> specify sound card id
-- @return a table with lower and raise function (both take optional percentage as param (default: 1))
function volume(channel, typ, cardid)
    typ = typ or "alsa"
    cardid = cardid or 0
    if obvious[typ] == nil then
        obvious[typ] = require("obvious.volume_" .. typ)
        if typ == "alsa" then
            local org = obvious[typ]
            obvious[typ] = {
                lower = function (ch, v) org.lower(cardid, ch, v) end,
                raise = function (ch, v) org.raise(cardid, ch, v) end,
            }
        end
    end
    return {
        lower = function (perc) obvious[typ].lower(channel, perc) end,
        raise = function (perc) obvious[typ].raise(channel, perc) end,
    }
end

