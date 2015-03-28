--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local progressimage = { mt = {} }

local awful = require("awful")
local wibox = require("wibox")


--- Progressbar and Image Glue
-- @param args table with all relevant properties
-- @param args.x <i>(optional) </i> progressbar x offset
-- @param args.y <i>(optional) </i> progressbar y offset
-- @param args.width progressbar width
-- @param args.width progressbar height
-- @param args.draw_image_first <i>(default: true)</i> specify wether image or progress will be drawen first
-- @param args.image <i>(optional) </i> image to be displayed
-- @return `wibox.widget.imagebox` with property progress with is a `awful.widget.progressbar`, draw_image_first, draw_progress_first, swap_first
local function new(args)
    local img_first = args.draw_image_first == nil or args.draw_image_first
    local ret = wibox.widget.imagebox()
    ret.progress = awful.widget.progressbar(args)

    ret.progress.x = args.x or 0
    ret.progress.y = args.y or 0
    if args.image then
        ret:set_image(args.image)
    end

    local draw_image = ret.draw
    local draw_progress = ret.progress.draw
    ret.draw = function (box, wibox, cr, width, height)
        if img_first then draw_image(box, wibox, cr, width, height) end
        local w = args.width  or width
        local h = args.height or height
        cr:save()
        cr:translate(ret.progress.x, ret.progress.y)
        draw_progress(ret.progress, wibox, cr, w, h)
        cr:restore()
        if not img_first then draw_image(box, wibox, cr, width, height) end
    end

    ret.draw_image_first    = function ()  img_first = true   end
    ret.draw_progress_first = function ()  img_first = false  end
    ret.swap_first  = function ()  img_first = not img_first  end

    return ret
end

function progressimage.mt:__call(...)
    return new(...)
end

return setmetatable(progressimage, progressimage.mt)
