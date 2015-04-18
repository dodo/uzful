--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = { module = {}, string = {} }

local io = require("io")
local obvious = {}
local naughty = require("naughty")
local _, vicious = pcall(require, "vicious")
local unpack = unpack or table.unpack -- v5.1: unpack, v5.2: table.unpack
local capi = {
    timer = (type(timer) == 'table' and timer or require("gears.timer")),
}


local udev, ud = nil, nil
local function initudev()
    if udev then return true end
    if not util.module.exists('udev') then return false end
    udev = require("udev") -- https://github.com/dodo/lua-udev
    ud = udev()
    return true
end

local socket = nil
local function initsocket()
    if socket then return true end
    if not util.module.exists('socket') then return false end
    socket = require("socket") -- luarocks install luasocket
    return true
end


util.table = {
    update = function (t, set)
        for k, v in pairs(set) do
            t[k] = v
        end
        return t
    end,
    default = function (t, def)
        for k, v in pairs(def) do
            if t[k] == nil then
                t[k] = v
            end
        end
        return t
    end,
}

util.patch = {
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
    --- Install signal system into naughty for status updates
    -- It overrides `naughty.resume` and `naughty.suspend`.
    -- enables naughty
    naughty = function ()
        local signals = {}
        local suspended = false
        naughty.resume() -- just make sure to not be suspended
        local resume, suspend = naughty.resume, naughty.suspend
        naughty.is_suspended = function () return suspended end
        naughty.resume = function ()
            suspended = false
            naughty.emit_signal('resume')
            naughty.emit_signal('toggle', suspended)
            return resume()
        end
        naughty.suspend = function ()
            suspended = true
            naughty.emit_signal('suspend')
            naughty.emit_signal('toggle', suspended)
            return suspend()
        end
        naughty.emit_signal = function (name, ...)
            for _, handler in ipairs(signals[name] or {}) do
                handler(...)
            end
        end
        naughty.connect_signal = function (name, handler)
            signals[name] = signals[name] or {}
            table.insert(signals[name], handler)
        end
        naughty.remove_signal = function (name, handler)
            for i, fun in ipairs(signals[name] or {}) do
                if fun == handler then
                    table.remove(signals[name], i)
                    return
                end
            end
        end
    end,
    }

util.listen = {
    --- vicious listener generator
    -- generates an object that van be passed to `vicious.register`
    -- @param slot specify the way you want to get your data. should be smth like 'text' (string), or 'value' (number)
    -- @param callback the callback function wich will be invoked. can get the value
    vicious = function (slot, callback)
        local old_value = "text" == slot and "…" or 1
        local mname = "text" == slot and "markup" or slot
        ret = {}
        ret["set_" .. mname] = function (_, value)
                if value == old_value then return end
                old_value = value
                callback(value)
            end
        ret["get_" .. slot] = function ()
            return old_value
        end
        ret["get_" .. slot] = ret["get_" .. mname]
        return ret
    end,

    sysfs = function (opts, callback)
        if not initudev() or not initsocket() then
            return {
                callbacks = {callback},
                timer = (opts.timer or capi.timer({ timeout = opts.timeout or 0.1 })),
            }
        end
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
util.scan = {
    sysfs = function (typ, args)
        if not initudev() then
            return {properties = {}, sysattrs = {}, length = 0}
        end
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
function util.threshold(threshold, on, off)
    local old_value = -1
    return util.listen.vicious("value", function (value)
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
function util.volume(channel, typ, cardid)
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
function util.functionlist(list)
    local current = 1
    return {
        current = function () return current end,
        call = function (...) return list[current](...) end,
        next = function () current = current % #list + 1 end,
        prev = function () current  = current == 1 and #list or current - 1 end,
    }
end


-- from http://stackoverflow.com/questions/15429236/how-to-check-if-a-module-exists-in-lua
function util.module.exists(pkg, name)
    if not name then pkg, name = nil, pkg end
    pkg = pkg or package
    if pkg.loaded[name] then return true end
    for _, searcher in ipairs(pkg.searchers or pkg.loaders) do
        local loader = searcher(name)
        if type(loader) == 'function' then
            pkg.preload[name] = loader
            return true
        end
    end
    return false
end

function util.string.gsplit(s, sep, plain)
    local start = 1
    local done = false
    local function pass(i, j, ...)
        if i then
            local seg = s:sub(start, i - 1)
            start = j + 1
            return seg, ...
        else
            done = true
            return s:sub(start)
        end
    end
    return function ()
        if done then return end
        if sep == '' then done = true return s end
        return pass(s:find(sep, start, plain))
    end
end

function util.lineswrap(s, n)
    local lines = {}
    for line in util.string.gsplit(s, "\n") do lines[#lines+1] = line end
    while #lines > n do table.remove(lines, 1) end
    if #lines == 0 then return "\n" end
    return table.concat(lines, "\n")
end

function util.iscallable(object)
    if not object then return false end
    if type(object) == 'function' then return true end
    local metatable = getmetatable(object)
    if metatable and metatable.__call then return true end
    return false
end


return util
