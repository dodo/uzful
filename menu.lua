

local awful = require("awful")
local ipairs = ipairs
local table = table
local beautiful = nil
local vicious = nil

module("uzful.menu")


function init(btfl, vcs)
    beautiful = btfl
    vicious = vcs
end


function layouts(Layouts)
    local items = {}
    for _, layout in ipairs(Layouts) do
        local layout_name = awful.layout.getname(layout)
        table.insert(items, { layout_name,
            function ()
                awful.layout.set(layout)
            end,
            beautiful["layout_" .. layout_name] })
    end
    return awful.menu({ items = items })
end


function toggle_widgets ()
    local widgets = {}
    local show = true
    local toggle = function ()
        show = not show
        if show then
            for _, widget in ipairs(widgets) do
                vicious.activate(widget)
            end
        else
            for _, widget in ipairs(widgets) do
                vicious.unregister(widget, true)
            end
        end
    end
    local visible = function () return show end
    return { widgets = widgets, toggle = toggle, visible = visible }
end

