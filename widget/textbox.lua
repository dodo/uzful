---------------------------------------------------------------------------
-- @author Uli Schlachter
-- @author dodo
-- @copyright 2010 Uli Schlachter
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-510-g8b6adbf
---------------------------------------------------------------------------

local oopango = require("oopango")
local oocairo = require("oocairo")
local base = require("wibox.widget.base")
local beautiful = require("beautiful")
local type = type
local unpack = unpack
local setmetatable = setmetatable
local pairs = pairs

module("uzful.widget.textbox")

local function layout_create(cr)
    if oopango.cairo_layout_create then
        return oopango.cairo_layout_create(cr)
    end
    return oopango.cairo.layout_create(cr)
end

local function update_and_show(cr, layout)
    if oopango.cairo_update_layout then
        oopango.cairo_update_layout(cr, layout)
        oopango.cairo_show_layout(cr, layout)
    else
        oopango.cairo.update_layout(cr, layout)
        oopango.cairo.show_layout(cr, layout)
    end
end

-- Setup a pango layout for the given textbox and cairo context
local function setup_layout(box, cr, width, height)
    local layout = layout_create(cr)
    layout:set_alignment(box._align)
    layout:set_ellipsize(box._ellipsize)
    layout:set_wrap(box._wrap)
    layout:set_width(oopango.units_from_number(width))
    layout:set_height(oopango.units_from_number(height))

    if box._markup then
        layout:set_markup(box._text)
    else
        layout:set_text(box._text)
    end

    if box._font then
        layout:set_font_description(box._font)
    else
        layout:set_font_description(beautiful.get_font())
    end

    local ink, logical = layout:get_pixel_extents()
    local offset = 0
    if box._valign == "center" then
        offset = (height - logical.height) / 2
    elseif box._valign == "bottom" then
        offset = height - logical.height
    end
    if offset > 0 then
        cr:move_to(0, offset)
    end

    return layout
end

-- Get the size that the given textbox covers.
-- If layout is given, it's :get_width()/get_height() is honoured.
local function get_size(box, layout, width, height)
    local ret = {
        width = 0,
        height = 0
    }

    if box._text then
        local layout = layout

        if not layout then
            -- Create a temporary surface that we need for computing the extents :(
            local surface = oocairo.image_surface_create("argb32", 1, 1)
            local cr = oocairo.context_create(surface)
            layout = setup_layout(box, cr, width, height)
        end

        local ink, logical = layout:get_pixel_extents()

        ret.width = logical.width
        ret.height = logical.height
    end

    return ret
end

--- Draw the given textbox on the given cairo context in the given geometry
function draw(box, wibox, cr, width, height)
    if not box._text then return end

    local layout = setup_layout(box, cr, width, height)

    update_and_show(cr, layout)
end

--- Fit the given textbox
function fit(box, width, height)
    local res = get_size(box, nil, width, height)
    return res.width, res.height
end

-- Test if a text is valid for a textbox. If it isn't, a lua error will be thrown.
local function check_text(text, markup)
    local surface = oocairo.image_surface_create("argb32", 1, 1)
    local cr = oocairo.context_create(surface)
    local layout = layout_create(cr)

    if markup then
        layout:set_markup(text)
    else
        layout:set_text(text)
    end
end

--- Set a textbox' text.
-- @param text The text to set. This can contain pango markup (e.g. <b>bold</b>)
function set_markup(box, text)
    check_text(text, true)
    box._text = text
    box._markup = true
    box:emit_signal("widget::updated")
end

--- Set a textbox' text.
-- @param text The text to display. Pango markup is ignored and shown as-is.
function set_text(box, text)
    check_text(text, false)
    box._text = text
    box._markup = false
    box:emit_signal("widget::updated")
end

--- Set a textbox' ellipsize mode.
-- @param mode Where should long lines be shortened? "start", "middle" or "end"
function set_ellipsize(box, mode)
    local allowed = { none = true, start = true, middle = true, ["end"] = true }
    if allowed[mode] then
        box._ellipsize = mode
        box:emit_signal("widget::updated")
    end
end

--- Set a textbox' wrap mode.
-- @param mode Where to wrap? After "word", "char" or "word_char"
function set_wrap(box, mode)
    local allowed = { word = true, char = true, word_char = true }
    if allowed[mode] then
        box._wrap = mode
        box:emit_signal("widget::updated")
    end
end

--- Set a textbox' vertical alignment
-- @param mode Where should the textbox be drawn? "top", "center" or "bottom"
function set_valign(box, mode)
    local allowed = { top = true, center = true, bottom = true }
    if allowed[mode] then
        box._valign = mode
        box:emit_signal("widget::updated")
    end
end

--- Set a textbox' vertical alignment
-- @param mode Where should the textbox be drawn? "left", "center" or "right"
function set_align(box, mode)
    local allowed = { left = true, center = true, right = true }
    if allowed[mode] then
        box._align = mode
        box:emit_signal("widget::updated")
    end
end

-- Returns a new textbox
local function new()
    local ret = base.make_widget()

    for k, v in pairs(_M) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._ellipsize = "end"
    ret._wrap = "word_char"
    ret._valign = "center"
    ret._align = "left"

    return ret
end

setmetatable(_M, { __call = function (_, ...) return new(...) end })

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80
