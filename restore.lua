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
local wibox = require('wibox')
local beautiful = require("beautiful")
local capi = {
    awesome = awesome,
    screen = screen,
    client = client,
}

local layouts = {}

module('uzful.restore') -- savery

--- example usage
-- myrestorelist = uzful.restore(layouts)
-- if myrestorelist[s].length > 0 then
--     myrestorelist[s].widget = uzful.widget.infobox({ screen = s,
--             size = function () return myrestorelist[s].fit() end,
--             position = "top", align = "left",
--             visible = true, ontop = true,
--             widget = myrestorelist[s].layout })
--     myrestorelist[s].layout:connect_signal("widget::updated", function ()
--         if myrestorelist[s].length == 0 then
--                 myrestorelist[s].widget:hide()
--                 myrestorelist[s].widget.screen = nil
--         else
--             myrestorelist[s].widget:update()
--         end
--     end)
-- end


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
    if data == nil then
        data = {}
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
    if data == nil then
        data = {}
    end
    if cmd == 'set' and data.geometry ~= nil then
        client:geometry(data.geometry)
    elseif cmd == 'get' then
        data.geometry = client:geometry()
    end
    for _,prop in ipairs({"screen","instance","pid"}) do
        if cmd == 'get' or data[prop] == nil then
            data[prop] = client[prop]
        elseif cmd == 'set' then
            if prop ~= "pid" then
                client[prop] = data[prop]
            end
        end
    end
    for _,prop in ipairs({"floating","floating_geometry","sticky","ontop","minimized","maximized","hidden","fullscreen","modal","maximized_horizontal","maximized_vertical","skip_taskbar"}) do
        if cmd == 'get' or data[prop] == nil then
            data[prop] = awful.client.property.get(client, prop)
        elseif cmd == 'set' then
            awful.client.property.set(client, prop, data[prop])
        end
    end
    return data
end


function disconnect()
    local data = {}
    for s = 1, capi.screen.count() do
        local screen = capi.screen[s]
        local screendata = data[s] or {}
        data[s] = screendata
        for t,tag in ipairs(screen:tags()) do
            screendata[t] = update_tag('get', tag, screendata[t])
        end
    end
    data.windows = {} -- always override last windows history
    for _, client in ipairs(capi.client.get(--[[all]])) do
        local window = update_window('get', client, { tags = {} })
        -- get tags numbers
        for _, tag in ipairs(client:tags()) do
            table.insert(window.tags, awful.tag.getidx(tag))
        end
        -- get command
        local f = io.popen("ps --no-headers o args " .. client.pid, "r")
        window.command = f:read() or ""
        f:close()
        -- save
        table.insert(data.windows, window)
    end


    print "* write savepoint"
    local f = io.open(awful.util.getdir("config") .. "/savepoint.lua", "w+")
    f:write("return " .. table2string(data, ""))
    f:close()

end


local function create_control(text, callback)
    local theme = beautiful.get()
    local ret = wibox.widget.textbox()
    ret:set_align("center")
    ret:set_text(text)
    local bg  = wibox.widget.background()
    bg:set_widget(ret)
    bg:set_fg(theme.fg_normal)
    bg:set_bg(theme.bg_normal)
    ret:connect_signal("mouse::enter", function ()
        bg:set_fg(theme.fg_focus)
        bg:set_bg(theme.bg_focus)
    end)
    ret:connect_signal("mouse::leave", function ()
        bg:set_fg(theme.fg_normal)
        bg:set_bg(theme.bg_normal)
    end)
    ret:buttons(awful.button({ }, 1, callback))
    return bg
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
    data.pids = {}

    capi.awesome.connect_signal("exit", disconnect)

    local ret = {}
    -- make sure, that we have at least a screen and tag structure
    for s = 1, capi.screen.count() do
        local screen = capi.screen[s]
        local screendata = data[s]
        if screendata == nil then
            screendata = {}
            data[s] = screendata
        end
        for t,tag in ipairs(screen:tags()) do
            screendata[t] = update_tag('set', tag, screendata[t])
        end

        ret[s] = setmetatable({
            layout = wibox.layout.flex.vertical(),
            controls = wibox.layout.flex.horizontal(),
            length = 0,
            fit = function ()
                return 242, ((ret[s].length + 1) * 12)
            end,
        }, { __mode = 'k' })
        local ignorecontrol = create_control("ignore", function ()
            ret[s].length = 0
            for pid, _ in pairs(data.pids) do
                data.pids[pid] = nil
            end
            ret[s].layout:reset()
        end)
        ret[s].controls:add(ignorecontrol)
        ret[s].controls:add(create_control("spawn", function ()
            -- remove spawncontrol to disable retry
            ret[s].controls:reset()
            ret[s].controls:add(ignorecontrol)
            -- spawn new process here and update pid at every place
            local pids = {}
            for pid, _ in pairs(data.pids) do
                local entry = data.pids[pid]
                local spawn = awful.util.spawn(entry.window.command)
                if type(spawn) == "number" then
                    entry.text:set_text(spawn .. "\t" .. entry.window.command)
                    data.pids[pid] = nil
                    entry.window.pid = spawn
                    pids[spawn] = entry
                    ret[entry.window.screen][pid] = nil
                    ret[entry.window.screen][spawn] = entry
                else
                    -- fails
                    ret[s].length = ret[s].length - 1
                    entry.text:set_text(spawn or "broken")
                end
            end
            data.pids = pids
        end))
        ret[s].layout:add(ret[s].controls)
    end

    if data.windows == nil then
        data.windows = {}
    else
        for _,window in ipairs(data.windows) do
            data.pids[window.pid] = window
        end
    end

    for pid, window in pairs(data.pids) do
        window.command = window.command or ""
        local entry = {
            window = window,
            text = wibox.widget.textbox(),
        }
        local w = ret[window.screen]
        entry.text:set_text(window.pid .. "\t" .. window.command)
        w.length = w.length + 1
        w.layout:add(entry.text)
        w[window.pid] = entry
        data.pids[window.pid] = entry -- kill switch
    end

    capi.client.connect_signal("manage", function (client)
        local window = data.pids[client.pid]
        if window ~= nil then
            window = window.window
            print("alife!",client.pid,window.command)
            update_window('set', client, window)
            -- get all tag userdatas
            local tags = {}
            local capitags = capi.screen[client.screen]:tags()
            for _, t in ipairs(window.tags or {}) do
                table.insert(tags, capitags[t])
            end
            client:tags(tags)

            local w = ret[client.screen]
            data.pids[client.pid] = nil
            w.length = w.length - 1
            w.layout:reset()
            w.layout:add(w.controls)
            for _,c in pairs(data.pids) do
                w.layout:add(c.text)
            end
        end
    end)

    return ret
end

setmetatable(_M, { __call = function (_, ...) return connect(...) end })

