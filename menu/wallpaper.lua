--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local wallpaper = { mt = {} }

local floor = math.floor
local span = require("uzful.widget.span")
local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local cairo = require("lgi").cairo
local capi = {
    screen = screen,
    mouse = mouse,
}

local awsetbg_params = {
    maximize   = "maximized",
    center     = "centered",
    tile       = "tiled",
}

--- Feed it with:
-- theme.wallpapers = {
--     "/normal/path/to/a/picture.ext",
--     {"/normal/path/to/a/smaller/picture.ext", center = true},
--     "/normal/path/to/a/picture.ext",
--     …
-- }
-- uzful.menu.wallpaper.menu(theme.wallpapers)


local table_update = function (t, set)
    for k, v in pairs(set) do
        t[k] = v
    end
    return t
end

function wallpaper.exec(item, menu)
    local sel = menu.parent.items[menu.parent.sel]
    local fun = "maximized"
    for key, name in pairs(awsetbg_params) do
        if sel._item[key] then
            fun = name
            break
        end
    end
    if menu.sel == 1 then
        gears.wallpaper[fun](sel._item[1], capi.mouse.screen)
    else
        for s= 1, capi.screen.count() do
            gears.wallpaper[fun](sel._item[1], s)
        end
    end
end

function wallpaper.menu(items)
    local ret = { layout = wibox.layout.fixed.vertical }
    local sub = ret
    for i, item in ipairs(items) do
        local e = {"", -- name
            { -- submenu
                {"apply",       wallpaper.exec, new = awful.menu.entry},
                {"all screens", wallpaper.exec, new = awful.menu.entry},
            }, new = wallpaper.entry } -- tell this is different
        if type(item) == 'table' then
            e[1] = item[1]
            e._item = item
        else
            e[1] = item -- assume this is a string
            e._item = {item}
        end
        if #sub == 8 then
            local newsub = { layout = wibox.layout.fixed.vertical }
            table.insert(sub, 1, {"moar", newsub, height = 14, new = wallpaper.fixentry })
            sub = newsub
        end
        table.insert(sub, e)
    end
    return ret
end

function wallpaper.fixentry(parent, args)
    args = args or {}
    local item = awful.menu.entry(parent, args)
    item.widget = span({widget = item.widget, height = args.height})
    item.height = args.height
    return item
end


function wallpaper.entry(parent, args)
    args = args or {}
    local g = capi.screen[capi.mouse.screen].geometry
    args.theme.height = args.height or floor(args.theme.width*g.height/g.width)
    args.file = args[1] or args.file or ""
    args.cmd = args[2] or args.cmd
    local ret = {}
    -- load wallpaper preview
    local img = gears.surface.load(args.file)
    if img then
        local iw = img:get_width()
        local ih = img:get_height()
        local width = args.theme.width
        local height = args.theme.height
        if args._item.center and (iw < g.width or ih < g.height) then
            local sw, sh = width / g.width, height / g.height
            local x = (g.width  - iw)*0.5--(width  + iw*sw*0.5)/sw
            local y = (g.height - ih)*0.5--(height + ih*sh*0.5)/sh
            local i = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
            local cr = cairo.Context(i)
            cr:scale(sw, sh)
            cr:set_source_surface(img, x, y)
            cr:paint()
            img = i
        elseif iw > width or ih > height then
            local w, h
            if ((height / ih) * iw) > width then
                w, h = height, (height / iw) * ih
            else
                w, h = (height / ih) * iw, height
            end
            -- We need to scale the image to size w x h
            local i = cairo.ImageSurface(cairo.Format.ARGB32, w, h)
            local cr = cairo.Context(i)
            cr:scale(w / iw, h / ih)
            cr:set_source_surface(img, 0, 0)
            cr:paint()
            img = i
        end
    end
    local imgbox = wibox.widget.imagebox()
    imgbox:set_image(img)

    return table_update(ret, {
        height = args.theme.height,
        _item = args._item,
        image = img,
        widget = imgbox,
        cmd = args.cmd,
        akey = key,
    })
end

function wallpaper.mt:__call(...)
    return wallpaper.entry(...)
end

return setmetatable(wallpaper, wallpaper.mt)
