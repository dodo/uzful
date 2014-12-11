--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local titlebar = { mt = {} }

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local uzful = { util = require("uzful.util") }
local surface = require("gears.surface")
local string = { format = string.format }
local esc = awful.util.escape
local Mirror = {east = "west", west = "east",
                south = "north", north = "south"}
local capi =
{
    client = client,
    screen = screen,
}

local function any(list, iter)
    for key, value in pairs(list) do
        if iter(value, key) == true then
            return true
        end
    end
    return false
end


local function coord(key, dir, geometry, size)
    local theme = beautiful.get()
    local border = theme.titlebar_border_width or theme.border_width or 0
    if dir == nil then
        return geometry[key]
    elseif dir == "north" then
        if key == "x" then
            return geometry["x"]
        else
            return geometry["y"] - size - border
        end
    elseif dir == "south" then
        if key == "x" then
            return geometry["x"]
        else
            return geometry["y"] + geometry["height"]
        end
    elseif dir == "east"  then
        if key == "x" then
            return geometry["x"] + geometry["width"]
        else
            return geometry["y"]
        end
    elseif dir == "west"  then
        if key == "x" then
            return geometry["x"] - size - border
        else
            return geometry["y"]
        end
    end
end


local function extent(key, dir, geometry, size)
    if dir == nil then
        return geometry[key]
    elseif dir == "north" or dir == "south" then
        if key == "width" then
            return geometry["width"]
        else
            return size
        end
    elseif dir == "east" or dir == "west" then
        if key == "width" then
            return size
        else
            return geometry["height"]
        end
    end
end

local function text(tb, c)
    local txt

    if c.minimized then
        txt = (esc(c.icon_name) or esc(c.name) or esc("<untitled>"))
    else
        txt = (esc(c.name) or esc("<untitled>"))
    end

    -- The text might be invalid, so use pcall
    if not pcall(tb.set_markup, tb, txt) then
        tb:set_markup("<i>&lt;Invalid text&gt;</i>")
    end

end



function titlebar.direction(bar, geometry)
    local dir = bar._dir
    local mirrored = bar._mirrored
    if dir == "auto" then
        geometry = geometry or bar.client:geometry()
        local area = capi.screen[bar.client.screen].workarea
        local out = {
            top    = geometry["y"] < bar.size,
            left   = geometry["x"] < bar.size,
            right  = geometry["x"] + geometry["width" ] + bar.size > area["width" ],
            bottom = geometry["y"] + geometry["height"] + bar.size > area["height"],
        }

        if (out.left and out.right) or (out.top and out.bottom) then
            return nil
        end

        if geometry["width"] > geometry["height"] then
            if out.left then
                if out.right then
                    if out.top then
                        return "south"
                    else
                        if mirrored and not out.bottom then
                            return "south"
                        else
                            return "north"
                        end
                    end
                else
                    if mirrored and not out.left then
                        return "west"
                    else
                        return "east"
                    end
                end
            else
                if mirrored and not out.right then
                    return "east"
                else
                    return "west"
                end
            end
        else
            if out.top then
                if out.bottom then
                    if out.left then
                        return "east"
                    else
                        if mirrored and not out.right then
                            return "east"
                        else
                            return "west"
                        end
                    end
                else
                    if mirrored and not out.top then
                        return "north"
                    else
                        return "south"
                    end
                end
            else
                if mirrored and not out.bottom then
                    return "south"
                else
                    return "north"
                end
            end
        end
    else
       return dir
    end
end


function titlebar.toggle(bar)
    bar._mirrored = not bar._mirrored
    bar:update()
end


function titlebar.visiblity(bar)
    local c = bar.client
    local w = bar.widget
    local geometry = c:geometry()
    local d = bar:direction(geometry)
    if d == nil then
        w.visible = false
    else
        w.visible =
            (c.sticky or any(c:tags(), function (t) return t.selected end))
            and (not (c.hidden     or
                      c.minimized  or
                      c.fullscreen )
            and awful.layout.get(c.screen) == awful.layout.suit.floating
            or  awful.client.floating.get(c) )
    end
    c.skip_taskbar = w.visible
end


function titlebar.color(bar, args)
    args = args or {}
    local w = bar.widget
    local theme = beautiful.get()
    if capi.client.focus == bar.client then
        w:set_fg(args.fg_focus or theme.titlebar_fg_focus or theme.fg_focus)
        w:set_bg(args.bg_focus or theme.titlebar_bg_focus or theme.bg_focus)
        w.border_color = args.border_focus or theme.titlebar_border_focus or theme.border_focus
    else
        w:set_fg(args.fg_normal or theme.titlebar_fg_normal or theme.fg_normal)
        w:set_bg(args.bg_normal or theme.titlebar_bg_normal or theme.bg_normal)
        w.border_color = args.border_normal or theme.titlebar_border_normal or theme.border_normal
    end
end

function titlebar.update(bar)
    local w = bar.widget
    local geometry = bar.client:geometry()
    local d = bar:direction(geometry)
    if d ~= nil then
        w.height = extent("height", d, geometry, bar.size)
        w.width  = extent("width",  d, geometry, bar.size)
        w.y = coord("y", d, geometry, bar.size)
        w.x = coord("x", d, geometry, bar.size)
        if d == "south" then d = "north" end
        bar.rotation:set_direction(d)
    end
    bar:visiblity()
end


local function new(c, args)
    args = args or {}

    local ret = {}

    local theme = beautiful.get()
    local box = wibox(uzful.util.table.update({
        border_width = theme.titlebar_border_width or theme.border_width or 0,
        border_color = theme.titlebar_border_normal or theme.border_normal,
        type = "utility",
    }, args))
    ret.widget = box
    ret.client = c

    local dir = args.dir or "auto"
    local mirrored = args.mirror or false
    local size = args.size or theme.menu_height
    ret.size = size
    ret._dir = dir
    ret._mirrored = mirrored

    ret.rotation = wibox.layout.rotate()
    box.screen = c.screen
    box.ontop = true
    box:set_widget(ret.rotation)

    ret.rotation:buttons(awful.button({ }, 1, function ()
        capi.client.focus = c
        c:raise()
    end))

    local signals = {}
    local set_geometry = function () ret:update() end
    signals["property::width"]    = set_geometry
    signals["property::height"]   = set_geometry
    local toggle_focus = function () ret:color(args) end
    signals["unfocus"] = toggle_focus
    signals["focus"]   = toggle_focus
    local set_visibility = function () ret:visiblity() end
    signals["tagged"]                       = set_visibility
    signals["untagged"]                     = set_visibility
    signals["property::hidden"]             = set_visibility
    signals["property::minimized"]          = set_visibility
    signals["property::fullscreen"]         = set_visibility
--     signals["property::sticky"]   = function ()
--         controls.sticky.update_image()
--         ret:visiblity()
--     end
    signals["property::x"] = function ()
        local geometry = c:geometry()
        local d = ret:direction(geometry)
        if d ~= nil then
            box.x = coord("x", d, geometry, ret.size)
        end
        ret:visiblity()
        ret.widget.draw()
    end
    signals["property::y"] = function ()
        local geometry = c:geometry()
        local d = ret:direction(geometry)
        if d ~= nil then
            box.y = coord("y", d, geometry, ret.size)
        end
        ret:visiblity()
        ret.widget.draw()
    end
    signals["unmanage"] = function ()
        for signal, callback in pairs(signals) do
            c:disconnect_signal(signal, callback)
        end
        box.visible = false
        box:set_widget(nil)
        awful.client.property.set(c, "titlebar", nil)
    end


    for signal, callback in pairs(signals) do
        c:connect_signal(signal, callback)
    end

    for k, v in pairs(titlebar) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret:color()
    ret:update()
    awful.client.property.set(c, "titlebar", ret)

    return ret
end


capi.client.add_signal("property::titlebar")

local update_titlebars = function(tag)
    for _, c in ipairs(tag:clients()) do
        local bar = awful.client.property.get(c, "titlebar")
        if bar ~= nil then
            bar:visiblity()
        end
    end
end

-- mirror the titlebar to the other side
function titlebar.mirror(c)
    local bar = awful.client.property.get(c, "titlebar")
    if bar ~= nil then
        bar:toggle()
    end
end

awful.tag.attached_connect_signal(nil, "property::selected", update_titlebars)
awful.tag.attached_connect_signal(nil, "property::hide",     update_titlebars)


function titlebar.mt:__call(...)
    return new(...)
end

return setmetatable(titlebar, titlebar.mt)
