-- I want to be your savery

local restore = { mt = {} }

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
		local s, _ = string.gsub(value, "\n", "")
        res = res .. '"' .. s .. '"'
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
    for _,prop in ipairs({"floating","floating_geometry","sticky","ontop","minimized","maximized","hidden","fullscreen","modal","maximized_horizontal","maximized_vertical","skip_taskbar"}) do
        if cmd == 'get' or data[prop] == nil then
            data[prop] = awful.client.property.get(client, prop)
        elseif cmd == 'set' then
            if prop ~= "floating_geometry" then
                awful.client.property.set(client, prop, data[prop])
            end
        end
    end
    for _,prop in ipairs({"instance","pid","screen"}) do
        if cmd == 'get' or data[prop] == nil then
            data[prop] = client[prop]
        elseif cmd == 'set' then
            if prop == "screen" then
                if data.screen > capi.screen.count() then
                    data.screen = capi.screen.count()
                end
                client[prop] = data[prop]
            end
        end
    end
    if cmd == 'set' and data.floating_geometry ~= nil then
        awful.client.floating.set(client, client.floating)
    end
    return data
end


local function get_command(pid)
    if pid == 0 then
        return ""
    else
        return awful.util.pread("ps --no-headers o args " .. pid)
    end
end


-- load savepoint data and prepare it as always same looking data structure
local function load(filename)
    print "* load savepoint"
    local data = {}
    local f = io.open(awful.util.getdir("config") .. "/" .. filename .. ".lua") -- FIXME
    if f ~= nil then
        f:close()
        data = require(filename)
    end

    return data
end

local function get_tag_numbers(tags)
    local ret = {}
    -- get tags numbers
    for _, tag in ipairs(tags) do
        table.insert(ret, awful.tag.getidx(tag))
    end
    return ret
end


function restore.disconnect(filename)
    filename = filename or "_savepoint"
    local data = load(filename)
    for s = 1, capi.screen.count() do
        local screendata = data[s] or {}
        data[s] = screendata
        screendata.tags = get_tag_numbers(awful.tag.selectedlist(s))
        for t,tag in ipairs(awful.tag.gettags(s)) do
            screendata[t] = update_tag('get', tag, screendata[t])
        end
    end
    data.windows = {} -- always override last windows history
    for _, client in ipairs(capi.client.get(--[[all]])) do
        if client.pid ~= 0 then
            local window = update_window('get', client, {
                tags = get_tag_numbers(client:tags()),
                command = get_command(client.pid),
                id = client.window,
            })
            -- save
            table.insert(data.windows, window)
        end
    end


    print "* write savepoint"
    local f = io.open(awful.util.getdir("config") .. "/" .. filename .. ".lua", "w+")
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

local function format_window_info(win)
    return ""..win.pid.. string.rep(" ",7-string.len(""..win.pid))..win.command
end

local function create_screen_info(screen)
    local ret
    ret = {
        layout = wibox.layout.flex.vertical(),
        controls = wibox.layout.flex.horizontal(),
        windows = setmetatable({}, {__mode = 'v'}),
        length = 0,
        fit = function ()
            return 242, ((ret.length + 1) * 12)
        end,
        rebuild = function ()
            local l = ret.layout
            l:reset()
            l:add(ret.controls)
            -- TODO show only from current tags
            for id,win in pairs(ret.windows) do
                if not win._removed then
                    l:add(win.text)
                end
            end
        end,
    }

    local ignorecontrol = create_control("ignore", function ()
        ret.length = 0
        for _, win in pairs(ret.windows) do
            win.remove()
        end
        ret.layout:reset()
    end)
    ret.controls:add(ignorecontrol)
    ret.controls:add(create_control("spawn", function ()
        -- remove spawncontrol to disable retry
        ret.controls:reset()
        ret.controls:add(ignorecontrol)
        -- spawn new process here and update pid at every place
        for _, win in pairs(ret.windows) do
            local spawn = awful.util.spawn(win.command, true, win.screen)
            print("spawn",win.command,win.screen,win.pid,"->  "..spawn)
            if type(spawn) == "number" then
                win.pid = spawn
                win.text:set_text(format_window_info(win))
            else
                -- fails
                ret.length = ret.length - 1
                win.text:set_text(spawn or "broken" .. " " .. win.command)
            end
        end
    end))

    ret.layout:add(ret.controls)
    return ret
end

local function create_window(data, win)
    local count = capi.screen.count()
    win = win or {}
    if win.screen > count then
        win.screen = count
    end
    win.command = win.command or ""
    win.text = wibox.widget.textbox()
    win.text:set_text(format_window_info(win))
    win.remove = function ()
        data.ids[win.id] = nil
        win._removed = true
    end
    return win
end

local function get_tags(tags, screen)
    -- get all tag userdatas
    local ret = {}
    local capitags = awful.tag.gettags(screen or 1)
    for _, t in ipairs(tags or {}) do
        table.insert(ret, capitags[t])
    end
    return ret
end

function restore.connect(opts)
    opts = opts or {}
    opts.layouts = opts.layouts or awful.layout.layouts
    opts.filename = opts.filename or "_savepoint"
    for _, layout in ipairs(opts.layouts) do
        layouts[awful.layout.getname(layout)] = layout
    end

    local ret, data = {}
    if opts.load ~= false then
        data = load(opts.filename)
    end
    data = data or {}
    data.windows = data.windows or {}
    ret.ids = {}

    -- make sure, that we have at least a screen and tag structure
    for s = 1, capi.screen.count() do
        local screendata = data[s]
        if screendata == nil then
            screendata = {}
            data[s] = screendata
        end
        for t,tag in ipairs(awful.tag.gettags(s)) do
            screendata[t] = update_tag('set', tag, screendata[t])
        end
        if screendata.tags and #screendata.tags then
            awful.tag.viewmore(get_tags(screendata.tags, s), s)
        end
        if opts.info ~= false then
            ret[s] = create_screen_info(s)
        end
    end

    local randi = 0
    for _, window in ipairs(data.windows) do
        window = create_window(ret, window)
        if window.id == nil then
            randi = randi - 1
            window.id = randi
        end
        local win = ret[window.screen]
        if win then
            win.layout:add(window.text)
            win.length = win.length + 1
            win.windows[window.id] = window
            ret.ids[window.id] = window -- kill switch
        end
    end

    if opts.save ~= false then
        capi.awesome.connect_signal("exit", function ()
            restore.disconnect(opts.filename)
        end)
    end
    capi.client.connect_signal("manage", function (client)

        local window = ret.ids[client.window] -- matches after restart
        if window == nil then
            -- TODO better checks
            local cmd = get_command(client.pid)
            for id, win in pairs(ret.ids) do
                if win.command == cmd then
                    win.pid = client.pid
                    window = win
                    break
                end
            end
        end
        if window ~= nil then
            window = update_window('set', client, window)
            if window.tags and #window.tags then
                client:tags(get_tags(window.tags, client.screen))
            end
            local win = ret[client.screen]
            if win then
                win.length = win.length - 1
                window.remove()
                win.rebuild()
            end
        end
    end)

    data.windows = nil -- should be everything in ret.ids by now
    return ret
end

function restore.mt:__call(...)
    return restore.connect(...)
end

return setmetatable(restore, restore.mt)
