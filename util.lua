--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local print=print
local type = type
local pairs = pairs
local ipairs = ipairs
local io = require("io")
local obvious = {}
local assert = assert
local require = require
local vicious = require("vicious")
local socket = require("socket")   -- luarocks install luasocket
local udev = require("udev") -- https://github.com/dodo/lua-udev
local unpack = unpack or table.unpack -- v5.1: unpack, v5.2: table.unpack
local table_insert = table.insert
local capi = {
    timer = timer,
}

module("uzful.util")

local ud = udev()

table = {
    insert = table_insert,
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

    sysfs = function (opts, callback)
        if not callback then opts, callback = {}, opts end
        local ret = opts.handle
        if not ret then
            ret = { callbacks = {callback} }
            ret.mon = udev.monitor(ud, opts.monitor or "udev")
            assert(ret.mon:filter_subsystem_devtype(opts.subsystem, opts.devtype))
            ret.timer = opts.timer or capi.timer({ timeout = opts.timeout or 0.1 })
            ret.timer:connect_signal("timeout", function ()
                if #socket.select({ret.mon}, nil, 0) > 0 then
                    local device = ret.mon:receive()
                    if device then
                        local sysattrs = device:getsysattrs()
                        local properties = device:getproperties()
                        for _, cb in ipairs(ret.callbacks) do
                            cb(device, properties, sysattrs)
                        end
                        device:close()
                    else
                        print("no device!")
                    end
                end
            end)
            if not opts.timer then ret.timer:start() end
            ret.mon:start()
        else
            table.insert(ret.callbacks, callback)
        end
        return ret
    end,
    }

local function get_args(args, key)
    local arg = args[key]
    if arg and type(arg) ~= "table" then arg = {arg} end
    return unpack(arg or {})
end
scan = {
    sysfs = function (typ, args)
        if type(typ) == "table" then typ, args = nil, typ end
        typ = typ or "devices"
        args = args or {}
        local enum = udev.enumerate(ud)
        for _, k in ipairs({"subsystem","sysattr"}) do
            if args["no"..k] then enum["nomatch_"..k](enum, get_args(args, "no"..k)) end
            if args[k] then enum["match_"..k](enum, get_args(args, k)) end
        end
        for _, k in ipairs({"property","tag","parent","sysname"}) do
            if args[k] then enum["match_"..k](enum, get_args(args, k)) end
        end
        if args.syspath then
            if type(args.syspath) ~= "table" then args.syspath = {args.syspath} end
            for _, syspath in ipairs(args.syspath) do
                enum:addsyspath(syspath)
            end
        end
        if args.initialized then enum:match_initialized() end
        assert(enum["scan_"..typ](enum)) -- now scanning …
        local ret = {properties = {}, sysattrs = {}, length = 0}
        for _, path in ipairs(enum:getlist()) do
            print("got path:", path)
            ret.length = ret.length + 1
            local dev = udev.device.new_from_syspath(ud, path)
            table.insert(ret.properties, dev:getproperties())
            table.insert(ret.sysattrs, dev:getsysattrs())
            dev:close()
        end
        enum:close()
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


