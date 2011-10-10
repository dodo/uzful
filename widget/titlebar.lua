--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local uzful = { util = require("uzful.util") }
local string = { format = string.format }
local esc = awful.util.escape
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type
local print = print
local setmetatable = setmetatable
local capi =
{
    client = client,
    screen = screen,
    oocairo = oocairo
}

local function any(list, iter)
    for key, value in pairs(list) do
        if iter(value, key) == true then
            return true
        end
    end
    return false
end

module("uzful.widget.titlebar")


local function coord(key, dir, geometry, size)
    if dir == "north" then
        if key == "x" then
            return geometry["x"]
        else
            return geometry["y"] - size
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
            return geometry["x"] - size
        else
            return geometry["y"]
        end
    end
end


local function extent(key, dir, geometry, size)
    if dir == "north" or dir == "south" then
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



function direction(bar, geometry)
    local dir = bar._dir
    geometry = geometry or bar.client:geometry()
    if dir == "auto" then
        if geometry["width"] > geometry["height"] then
            if geometry["x"] <= 0 then
                return "east"
            else
                return "west"
            end
        else
            if geometry["y"] <= 0 then
                return "south"
            else
                return "north"
            end
        end
    else
        if dir == "south" then
            return "north"
        else
            return dir
        end
    end
end


function visiblity(bar)
    local c = bar.client
    local w = bar.widget
    local geometry = c:geometry()
    local d = bar:direction(geometry)
    local area = capi.screen[c.screen].workarea
    w.visible = (c.sticky or any(c:tags(), function (t) return t.selected end))
        and (   not (c.hidden     or
                     c.minimized  or
                     c.fullscreen )
        and awful.layout.get(c.screen) == awful.layout.suit.floating
        or  awful.client.floating.get(c) )
    c.skip_taskbar = w.visible
end


function color(bar, args)
    args = args or {}
    local w = bar.widget
    local theme = beautiful.get()
    if capi.client.focus == bar.client then
        w:set_fg(args.fg_focus or theme.titlebar_fg_focus or theme.fg_focus)
        w:set_bg(args.bg_focus or theme.titlebar_bg_focus or theme.bg_focus)
    else
        w:set_fg(args.fg_normal or theme.titlebar_fg_normal or theme.fg_normal)
        w:set_bg(args.bg_normal or theme.titlebar_bg_normal or theme.bg_normal)
    end
end

function update(bar)
    local w = bar.widget
    local geometry = bar.client:geometry()
    local d = bar:direction(geometry)
    w.height = extent("height", d, geometry, bar.size)
    w.width  = extent("width",  d, geometry, bar.size)
    w.y = coord("y", d, geometry, bar.size)
    w.x = coord("x", d, geometry, bar.size)
    bar.rotation:set_direction(d)
    bar:visiblity()
end




function new(c, args)
    args = args or {}

    local ret = {}

    local theme = beautiful.get()
    local box = wibox(uzful.util.table.update({ type = "utility" }, args))
    ret.widget = box
    ret.client = c

    local dir = args.dir or "auto"
    local size = args.size or theme.menu_height
    ret.size = size
    ret._dir = dir

    local rot, ib, tb, m, l, r, f, buttons

    rot = wibox.layout.rotate()
    ib = wibox.widget.imagebox()
    tb = wibox.widget.textbox()
    m = wibox.layout.margin(tb, 4, 4)
    l = wibox.layout.fixed.horizontal()
    r = wibox.layout.fixed.horizontal()
    f = wibox.layout.align.horizontal()

    l:add(ib)
    l:add(m)

    ret.rotation = rot
    ret.text = tb
    ret.icon = ib

    box.screen = c.screen
    box.ontop = true--c.ontop

    buttons = {
        { "sticky",    state = true, function () c.sticky = not c.sticky end },
        { "ontop",     state = true, function () c.ontop  = not c.ontop  end },
        { "maximized", state = true, function ()
                c.maximized_horizontal = not c.maximized_horizontal
                c.maximized_vertical   = not c.maximized_vertical
            end },
        { "floating",  state = true, function () awful.client.floating.toggle(c) end },
        { "close", function () c:kill() end },
    }

    local controls = {}
    local image, img, key
    for _, con in ipairs(buttons) do
        local name = con[1]
        local control = {}
        controls[name] = control

        for _, focustype in ipairs({"focus", "normal"}) do
            local focusstate = {}
            control[focustype] = focusstate
            for state, val in pairs({active = true, inactive = false}) do

                if con.state then
                    key = string.format(
                        "titlebar_%s_button_%s_%s", name, focustype, state)
                else
                    key = string.format(
                        "titlebar_%s_button_%s", name, focustype)
                end
                image = args[key] or theme[key]

                if type(image) == "string" then
                    img = capi.oocairo.image_surface_create_from_png(image)
                elseif type(image) == "userdata" and image.type and image:type() == "cairo_surface_t" then
                    img = image
                elseif type(image) == "userdata" and image._NAME and image._NAME == "cairo surface object" then
                    img = image
                end
                focusstate[val] = img
            end
        end

        control.image = wibox.widget.imagebox()
        control.state = "normal"

        control.update_image = function ()
            control.image:set_image(control[control.state][not (not c[name])])
        end
        control.image:connect_signal("mouse::enter", function ()
            control.state = "focus"
            control.update_image()
        end)
        control.image:connect_signal("mouse::leave", function ()
            control.state = "normal"
            control.update_image()
        end)

        if #con > 1 and type(con[2]) == "function" then
            control.image:buttons(awful.button({ }, 1, con[2]))
        end

        control.update_image()
        r:add(control.image)
    end

    ret.controls = controls

    text(tb, c)
    ib:set_image(c.icon)
    f:set_left(l)
    f:set_right(r)
    rot:set_widget(f)
    box:set_widget(rot)

    box:connect_signal("mouse::enter", function ()
        capi.client.focus = c
    end)

    local signals = {}
    signals["property::icon"]     = function () ib:set_image(c.icon)             end
    signals["property::ontop"]    = function () controls.ontop.update_image()    end
    signals["property::floating"] = function () controls.floating.update_image() end
    local set_geometry = function () ret:update() end
    signals["property::width"]    = set_geometry
    signals["property::height"]   = set_geometry
    local toggle_focus = function () ret:color(args) end
    signals["unfocus"] = toggle_focus
    signals["focus"]   = toggle_focus
    local set_name = function () text(tb, c) end
    signals["property::name"]      = set_name
    signals["property::icon_name"] = set_name
    local set_visibility = function () ret:visiblity() end
    signals["tagged"]                       = set_visibility
    signals["untagged"]                     = set_visibility
    signals["property::hidden"]             = set_visibility
    signals["property::minimized"]          = set_visibility
    signals["property::fullscreen"]         = set_visibility
    signals["property::sticky"]   = function ()
        controls.sticky.update_image()
        ret:visiblity()
    end
    signals["property::x"] = function ()
        local geometry = c:geometry()
        local d = ret:direction(geometry)
        box.x = coord("x", d, geometry, size)
        ret:visiblity()
    end
    signals["property::y"] = function ()
        local geometry = c:geometry()
        local d = ret:direction(geometry)
        box.y = coord("y", d, geometry, size)
        ret:visiblity()
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

    for _, k in ipairs({"visiblity", "update", "color", "direction"}) do
        ret[k] = _M[k]
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

awful.tag.attached_connect_signal(nil, "property::selected", update_titlebars)
awful.tag.attached_connect_signal(nil, "property::hide",     update_titlebars)

setmetatable(_M, { __call = function (_, ...) return new(...) end })
