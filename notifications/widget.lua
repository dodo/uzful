--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local notifications = { mt = {} }

local os = require('os')
local wibox = require("wibox")
local awful = require("awful")
local naughty = require("naughty")
local _, vicious = pcall(require, "vicious")
local _, helpers = pcall(require, "vicious.helpers")
local beautiful = require("beautiful")
local uzful = { widget = { scroll = require('uzful.widget.scroll') } }
local widgets = {}
local capi = {
    mouse = mouse,
    screen = screen }


local mt = {}
local data = {}

function notifications.patch()
    local notify = naughty.notify
    naughty.notify = function (args)
        local notification = notify(args)
        notifications.update(notification, args)
        return notification
    end
end


function notifications.update(notification, args)
    args = args or {}
    local preset = args.preset or naughty.config.default_preset or {}
    local icon = args.icon or preset.icon
    local text = args.text or preset.text or ""
    local screen = args.screen or preset.screen or 1
    local theme = beautiful.get()
    local color = {
        fg_normal = args.fg or preset.fg or theme.fg_normal or '#ffffff',
        bg_normal = args.bg or preset.bg or theme.bg_normal or '#535d6c',
        border_color = args.border_color or preset.border_color or
                       theme.bg_focus or '#535d6c',
    }
    local new_data = {
        notification = notification,
        screen = screen,
        theme = color,
        text = text,
        icon = icon }
    table.insert(data, new_data)

    local updates = {}
    for wid, conf in pairs(widgets) do
        if conf.screen == screen then
            updates[wid] = wid
        end
    end
    for _,wid in pairs(updates) do
        wid:add(new_data)
    end
end


function mt.add(wid, args)
    local conf = widgets[wid]
    if conf == nil or not conf.visible then return end
    wid.number = wid.number + 1

    local setMarkup = function ()
        wid.text:set_markup(helpers.format(conf.format, { wid.number }))
    end
    setMarkup()
    local item
    local mouse_fun = function (menuitem, menu)
        wid.number = wid.number - 1
        args.notification.box.visible = true
        args.notification.die()
        setMarkup()
        local i = awful.util.table.hasitem(args)
        if i then
            table.remove(data, i)
        end
        return (wid.number ~= 0), function ()
            menu:delete(menuitem)
            if #menu.items * (menu.height + menu.theme.border_width) +
                menu.theme.border_width < menu.layout.max then
                menu.layout:set_offset(0)
                if wid.number then
                    menu:update()
                else
                    self:hide()
                end
            end
        end
    end
    local text = os.date("[%H:%M:%S]  ") .. (args.text or "")
    wid.menu:add({ theme = args.theme or {}, text, mouse_fun, args.icon }, 1)
    wid.menu:update()
end


function mt.show(wid, args)
    local conf = widgets[wid]
    if conf == nil then return end
    if conf.visible then
        conf.menu_args = args
        wid.menu.layout:set_offset(0)
        wid.menu.layout.timer:start()
        vid.menu:update()
        wid.menu:show(args)
    end
end


function mt.hide(wid)
    local conf = widgets[wid]
    if conf == nil then return end
    if conf.visible then
        wid.menu:hide()
        if wid.menu.layout.timer.started then
            wid.menu.layout.timer:stop()
        end
    end
end


function mt.toggle_menu(wid, args)
    local conf = widgets[wid]
    if conf == nil then return end
    if conf.visible then
--         local x, y = wid.menu.wibox.x, wid.menu.wibox.y
        wid.menu:toggle(args)
        local w, h = wid.menu.wibox.width, wid.menu.wibox.height
        wid.menu.layout.size = { width = w , height = h }
        w, h = wid.menu.layout:fit(w, h)
        wid.menu.width, wid.menu.height = w, h
        wid.menu.wibox.width, wid.menu.wibox.height = w, h

        if wid.menu.wibox.visible then

            local geo = capi.screen[capi.mouse.screen].workarea
            local coords = capi.mouse.coords()
            coords.x = coords.x + 1
            coords.y = coords.y + 1
            wid.menu.wibox.x = coords.x < geo.x and geo.x or coords.x
            wid.menu.wibox.y = coords.y < geo.y and geo.y or coords.y

            local a, b, la, lb = "x", "y", "width", "height"
            if wid.menu.layout.dir == "vertical" then a, b, la, lb = b, a, lb, la end
            local screen_s = geo[b] + geo[lb]
            wid.menu.wibox[b] = wid.menu.wibox[b] + wid.menu.wibox[lb] > screen_s and
                    screen_s - wid.menu.wibox[lb] or wid.menu.wibox[b]

            wid.menu.layout.timer:start()
        elseif wid.menu.layout.timer.started then
            wid.menu.layout.timer:stop()
        end
    end
end


function mt.enable(wid)
    local conf = widgets[wid]
    if conf == nil or conf.visible then return end
    conf.visible = true
    wid.text:set_markup(helpers.format(conf.format, { wid.number }))
    naughty.suspend()
end


function mt.disable(wid)
    local conf = widgets[wid]
    if conf == nil or not conf.visible then return end
    local new = {}
    for _, v in pairs(data) do
        if v.screen ~= conf.screen then
            table.insert(new, v)
        end
    end
    wid:hide()
    for i = 1, #wid.menu.items do
        wid.menu:delete(conf.menu.len + 1)
    end
    data = new
    wid.number = 0
    conf.visible = false
    wid.menu.layout:set_offset(0)
    wid.text:set_markup(conf.disabled)
    naughty.resume()
end


function mt.toggle(wid)
    local conf = widgets[wid]
    if conf == nil then return end
    if conf.visible then
        wid:disable()
    else
        wid:enable()
    end
end


local function new(screen, args)
    screen = screen or 1
    args = args or {}
    local ret

    local conf = {
        disabled = helpers.format(args.disabled or "$1", { "⤫" }),
        format = args.text or "$1",
        menu = args.menu or {},
        visible = args.visible ~= nil and args.visible,
        screen = screen }
    conf.menu.max = conf.menu.max or args.max or 345
    conf.menu.layout = conf.menu.layout or function (...)
        local layout = uzful.widget.scroll("vertical", conf.menu.max, {
            widget = wibox.layout.flex.vertical(...),
            fit = nil,
        })
        layout.add   = function (scroll, ...) return scroll.widget:add(...) end
        layout.reset = function (scroll, ...) return scroll.widget:reset(...) end
        return layout
    end

    ret = {
        menu = awful.menu(conf.menu),
        text = wibox.widget.textbox(),
        number = 0 }
    setmetatable(ret, mt)
    widgets[ret] = conf
    conf.menu.len = #ret.menu.items
    local update = ret.menu.update
    ret.menu.update = function (...)
        local x, y = ret.menu.wibox.x, ret.menu.wibox.y
        update(...)
        local w, h = ret.menu.wibox.width, ret.menu.wibox.height
        ret.menu.layout.size = { width = w , height = h }
        w, h = ret.menu.layout:fit(w, h)
        ret.menu.wibox.x, ret.menu.wibox.y = x, y
        ret.menu.width, ret.menu.height = w, h
        ret.menu.wibox.width, ret.menu.wibox.height = w, h
    end

    for _, v in pairs(data) do
        if v.screen == screen then
            ret:add(v)
        end
    end

    conf.visible = not conf.visible
    ret:toggle()

    return ret
end

mt = { __index = mt }

function notifications.mt:__call(...)
    return new(...)
end
return setmetatable(notifications, notifications.mt)
