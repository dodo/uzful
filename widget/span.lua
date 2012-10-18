---------------------------------------------------------------------------
-- @author dodo
-- @copyright 2012 dodo
-- @release v3.4-797-g2752173
---------------------------------------------------------------------------

local base = require("wibox.widget.base")
local layout_base = require("wibox.layout.base")
local setmetatable = setmetatable
local pairs = pairs
local type = type

local print=print

module("uzful.widget.span")

local data = setmetatable({}, { __mode = "k" })

--- Draw this widget
function draw(box, wibox, cr, width, height)
    if not box.widget then
        return
    end
    layout_base.draw_widget(wibox, cr, box.widget, 0, 0, width, height)
end

--- Fit this widget into the given area
function fit(box, width, height)
    local w, h = 0, 0
    if box.widget then
        w, h = box.widget:fit(width, height)
    end
    if w ~= (data[box].width  or 0) then w = data[box].width  or w end
    if h ~= (data[box].height or 0) then h = data[box].height or h end
    print(w, h, width, height)
    return w, h
end


--- Set the graph height.
-- @param graph The graph.
-- @param height The height to set.
function set_height(box, height)
    data[box].height = height
    box:emit_signal("widget::updated")
    return box
end

--- Set the graph width.
-- @param graph The graph.
-- @param width The width to set.
function set_width(box, width)
    data[box].width = width
    box:emit_signal("widget::updated")
    return box
end

--- Set the widget that is drawn on top of the background
function set_widget(box, widget)
    if box.widget then
        box.widget:disconnect_signal("widget::updated", box._emit_updated)
    end
    if widget then
        base.check_widget(widget)
        widget:connect_signal("widget::updated", box._emit_updated)
    end
    box.widget = widget
    box._emit_updated()
end

local function new(args)
    args = args or {}
    local ret = base.make_widget()
    data[ret] = { width = args.width, height = args.height }

    for k, v in pairs(_M) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    if args.widget then
        ret:set_widget(args.widget)
    end

    return ret
end

setmetatable(_M, { __call = function (_, ...) return new(...) end })

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
