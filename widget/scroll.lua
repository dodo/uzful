---------------------------------------------------------------------------
-- @author Uli Schlachter
-- @author dodo
-- @copyright 2013 dodo
-- @release @AWESOME_VERSION@
---------------------------------------------------------------------------

local widget = require("wibox.widget")
local color = require("gears.color")
local layout = require("wibox.layout")
local surface = require("gears.surface")
local cairo = require("lgi").cairo
local setmetatable = setmetatable
local pairs = pairs
local type = type
local capi = { timer = (type(timer) == 'table' and timer or require("gears.timer")) }

-- uzful.widget.scroll
local scroll = { mt = {} }

local function arrow(ret, text, offset)
    local label = widget.textbox()
    label:set_markup(text)
    label:set_align("center")
    label:set_valign("center")
    local arrow = layout.rotate(label, ret.dir == "vertical" and "north" or "east")
    arrow:connect_signal("mouse::enter", function ()
        ret:scroll_with(offset, false)
    end)
    arrow:connect_signal("mouse::leave", function ()
        ret:scroll_with(0, true)
    end)
    return arrow
end



--- Draw this widget
function scroll:draw(wibox, cr, width, height)
    if not self.widget then
        return
    end
    layout.base.draw_widget(wibox, cr, self.control, 0, 0, width, height)
end


function scroll:set_offset(offset)
    self.offset[self.dir == "vertical" and "y" or "x"] = offset
end


--- Fit this widget into the given area
function scroll:fit(width, height)
    if not self.widget then
        return 0, 0
    end
    if self.inner_fit then width, height = self:inner_fit(width, height) end
    local s, a, b = { w = width, h = height }, "w", "h"
    if self.dir == "vertical" then a, b = b, a end
    if s[a] < 1 then s[a] = 1 end
        if self.control.third then s[a] = s[a] + 9 end -- FIXME 9 is the height of the arrow
    s.w, s.h = self.widget:fit(s.w, s.h)
    if self.control.third then s[a] = s[a] + 9 end -- FIXME 9 is the height of the arrow
    if s[a] > self.max then s[a] = self.max end
    self.cur = s
    return s.w, s.h
end

--- Set the widget that is drawn on top of the background
function scroll:set_widget(...)
    self.control:set_second(...)
    self.widget = self.control.second
    if self.widget.__hooked == self then return end
    self.widget.__hooked = self
    local draw_widget = self.widget.draw
    self.widget.draw = function (widget, wibox, cr, width, height)
        local a, b, s = "w", "h", { w = self.size.width, h = self.size.height }
        if self.dir == "vertical" then a, b = b, a end
        cr:save()
        cr:translate(-self.offset.x, -self.offset.y)
        draw_widget(widget, wibox, cr, s.w, s.h)
        cr:restore()
    end
end


function scroll:scrolling()
    if self.by == 0 then return end
    local offset = self.offset[self.dir == "vertical" and "y" or "x"] + self.by
    if offset <= 0 then
        offset = 0
    else
        local size = self.cur[self.dir == "vertical" and "h" or "w"]
        local _max = self.size[self.dir == "vertical" and "height" or "width"]
        size = size - 9 - 9 -- FIXME 9 is the height of the arrow
        if offset + size > _max then
            offset = _max - size
        end
    end
    self.offset[self.dir == "vertical" and "y" or "x"] = offset
    if self._singleshot then
        self._singleshot = false
        self.by = 0
    end
    self:emit_signal("widget::updated")
end


function scroll:scroll_with(offset, singleshot)
    self.by = offset or 0
    self._singleshot = singleshot
end


function scroll:scroll_by(offset, singleshot)
    self.by = self.by + (offset or 0)
    self._singleshot = singleshot
end


--- Returns a new scroll area layout.
-- @param dir scroll direction
-- @param max_size max size in direction (optional)
-- @param args.widget The widget to display (optional)
local function new(dir, max_size, args)
    args = args or {}
    local ret = widget.base.make_widget()
    local timer = capi.timer({ timeout = args.scroll_every or 0.05 })
    timer:connect_signal("timeout", function ()
        ret:scrolling()
    end)
    ret.by = 0
    ret.timer = timer
    ret._singleshot = false
    ret.dir = dir
    ret.max = max_size
    ret.inner_fit = args.fit
    ret.offset = { x = 0, y = 0 }
    ret.size   = { width = 0, height = 0 }

    for k, v in pairs(scroll) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    ret.control = layout.align[dir]()
    ret.arrow = {
        up =   arrow(ret, args.up_arrow   or "▴", -(args.scroll_by or 8)),
        down = arrow(ret, args.down_arrow or "▾",  (args.scroll_by or 8)),
    }
    ret.control:set_first(ret.arrow.up)
    ret.control:set_third(ret.arrow.down)
    ret.control:connect_signal("widget::updated", ret._emit_updated)

    ret:set_widget(args.widget)

    return ret
end

function scroll.mt:__call(...)
    return new(...)
end

return setmetatable(scroll, scroll.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
