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
local posix = require('posix')
local naughty = require('naughty')
local awful = require("awful")
local util = require("uzful.util")

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

function wallpaper.select_wallpaper(item)
    -- returns a string for the image
    -- if it's a random entry, select one file of the directory
    if item and type(item) == 'table' and item.random then
        if posix.stat(item[1], "type") ~= 'directory' then
            naughty.notify { title = "Error loading wallpaper: " .. item[1], text = 'random entries need to be a directory', timeout = 0 }
        else
            local all_files = util.scandir(item[1])

            if #all_files == 0 then
                return nil
            else
                while #all_files > 0 do
                    local n = math.random(1, #all_files + 1)
                    local target = item[1] .. '/' .. all_files[n]
                    -- if the file is not readable or does not exist (broken symlink), try next file
                    if awful.util.file_readable(target) then
                        return target
                    else
                        table.remove(all_files, n)
                    end
                end
            end
        end
    else
        if not awful.util.file_readable(item[1]) then
            naughty.notify { title = "Error loading wallpaper: " .. item[1], text = 'File does not exist or not readable', timeout = 0 }
        else
            return item[1]
        end
    end
end

function wallpaper.set_wallpaper(item, screen)
    local fun = "maximized"
    if not target then
        target = wallpaper.select_wallpaper(item)
    end
    if not target then
      -- select wallpaper gives appropriate feedback
      return
    end
    for key, name in pairs(awsetbg_params) do
        if item[key] then
            fun = name
            break
        end
    end
    if screen ~= nil then
        gears.wallpaper[fun](target, screen)
    else
        for s= 1, capi.screen.count() do
            gears.wallpaper[fun](target, s)
        end
    end
end

function wallpaper.exec(item, menu)
    local sel = menu.parent.items[menu.parent.sel]
    if menu.sel == 1 then
        wallpaper.set_wallpaper(sel._item, capi.mouse.screen)
    else
        wallpaper.set_wallpaper(sel._item)
    end
end

local function short_path(name)
    return string.gsub(name, ".*/(%w+)", "%1")
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
            e[1] = item
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
