-- I want to be your savery

local print = print
local type = type
local pairs = pairs
local ipairs = ipairs
local table = table
local require = require
local setmetatable = setmetatable
local io = require('io')
local awful = require('awful')
local capi = {
    awesome = awesome,
    screen = screen,
    client = client,
}

local layouts = {}

module('uzful.restore') -- savery

local table2string
local function lualine(value, key, indent)
    local res = indent
    if key ~= nil then
        res = res .. '["' .. key .. '"] = '
    end
    if type(value) == "table" then
        res = res .. table2string(value, indent)
    elseif type(value) == "string" then
        res = res .. '"' .. value .. '"'
    elseif type(value) == "boolean" then
        res = res .. (value and "true" or "false")
    else
        res = res .. value
    end
    res = res .. ",\n"
    return res
end

table2string = function (t, indent)
    local res = "{\n"
    local moarindent = indent .. "\t"
    for key, value in pairs(t) do
        res = res .. lualine(value,
            type(key) ~= "number" and key or nil,
            moarindent)
    end
    return res .. indent .. "}"
end

local function update_tag(cmd, tag, data)
    if cmd == 'set' then
        if data == nil then
            data = {}
        end
    end
    for _,prop in ipairs({"layout","mwfact","ncol","nmaster","windowfact"}) do
        if cmd == 'get' or data[prop] == nil then
            data[prop] = awful.tag.getproperty(tag, prop)
            if prop == 'layout' then
                data.layout = data.layout.name
            end
        elseif cmd == 'set' then
            if prop == 'layout' then
                awful.layout.set(layouts[data.layout], tag)
            else
                awful.tag.setproperty(tag, prop, data[prop])
            end
        end
    end
    return data
end


local function update_window(cmd, client, data)
    if cmd == 'set' then
        if data == nil  then
            data = {}
        end
    end
    return data
end


function disconnect()
    local data = {}
    for s = 1, capi.screen.count() do
        local screen = capi.screen[s]
        local screendata = data[s]
        for t,tag in ipairs(screen:tags()) do
            local tagdata = screendata[t]
            update_tag('get', tag, tagdata)
        end
    end
    data.windows = {} -- always override last windows history
    for _, client in ipairs(capi.client.get(--[[all]])) do
        local window = {
            tags = {},
            screen = client.screen,
            instance = client.instance,
            pid = client.pid,
            geometry = client:geometry(),
        }
        local f = io.popen("ps --no-headers o args " .. client.pid, "r")
        window.command = f:read()
        f:close()
        for _, prop in ipairs({"floating","floating_geometry","sticky","ontop","minimized","maximized","hidden","fullscreen","modal","maximized_horizontal","maximized_vertical","skip_taskbar"}) do
            window[prop] = awful.client.property.get(client, prop)
        end
        for _, tag in ipairs(client:tags()) do
            table.insert(window.tags, awful.tag.getidx(tag))
        end
        table.insert(data.windows, window)
    end


    print "* write savepoint"
    local f = io.open(awful.util.getdir("config") .. "/savepoint.lua", "w+")
    f:write("return " .. table2string(data, ""))
    f:close()

end


function connect(Layouts)
    for _, layout in ipairs(Layouts) do
        layouts[awful.layout.getname(layout)] = layout
    end

    print "* load savepoint"
    local data = {}
    local f = io.open(awful.util.getdir("config") .. "/savepoint.lua")
    if f ~= nil then
        f:close()
        data = require('savepoint')
    end

    capi.awesome.connect_signal("exit", disconnect)

    -- make sure, that we have at least a screen and tag structure
    if data.windows == nil then
        data.windows = {}
    end
    for s = 1, capi.screen.count() do
        local screen = capi.screen[s]
        local screendata = data[s]
        if screendata == nil then
            screendata = {}
            data[s] = screendata
        end
        for t,tag in ipairs(screen:tags()) do
            local tagdata = update_tag('set', tag, screendata[t])
            screendata[t] = tagdata
        end
   end

    -- start process again
    --for _, client in ipairs(capi.client.get(--[[all]])) do
    --    local screendata = savepoint[client.screen]
    --end

end

setmetatable(_M, { __call = function (_, ...) return connect(...) end })

