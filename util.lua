--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local obvious = {}
local require = require
local vicious = require("vicious")
local pairs = pairs

module("uzful.util")

table = {
    update = function (t, set)
        for k, v in pairs(set) do
            t[k] = v
        end
        return t
    end
    }

patch = {
    --- Enables always vicious.cache for all registered vicious widgets
    -- It overrides `vicious.register`.
    -- enable auto caching
    vicious = function ()
        local cache = {}
        local register = vicious.register
        vicious.register = function (widget, wtype, format, interval, warg)
             cache[wtype] = cache[wtype] or 0
            if cache[wtype] == 1 then
                vicious.cache(wtype)
            end
            cache[wtype] = cache[wtype] + 1
            register(widget, wtype, format, interval, warg)
        end
    end,
    }

listen = {
    --- vicious listener generator
    -- generates an object that van be passed to `vicious.register`
    -- @param slot specify the way you want to get your data. should be smth like 'text' (string), or 'value' (number)
    -- @param callback the callback function wich will be invoked. can get the value
    vicious = function (slot, callback)
        local old_value = "…"
        slot = "text" == slot and "markup" or slot
        ret = {}
        ret["set_" .. slot] = function (_, value)
                if value == old_value then return end
                old_value = value
                callback(value)
            end
        return ret
    end,
    }

--- vicious threshold generator
-- generates an object that can be passed to `vicious.register`
-- @param threshold number between 0 and 1
-- @param on when set_value invoked and value &gt; threshold then this function is called
-- @param off when set_value invoked and value &lt; threshold then this function is called
-- @return a table with property: set_value (similar to widget:set_value)
function threshold(threshold, on, off)
    local old_value = -1
    return listen.vicious("value", function (value)
            if value < threshold then off(value) else on(value) end
        end )
end

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

--- Changeable function list
-- you can change the function by next or prev which will be invoked by call
-- @param list list of functions
-- @return a table with methods: current, call, next, prev
function functionlist(list)
    local current = 1
    return {
        current = function () return current end,
        call = function (...) return list[current](...) end,
        next = function () current = current % #list + 1 end,
        prev = function () current  = current == 1 and #list or current - 1 end,
    }
end
