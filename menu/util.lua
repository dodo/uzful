--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local awful = require("awful")
local ipairs = ipairs
local table = table
local beautiful = require("beautiful")
local vicious = require("vicious")

module("uzful.menu.util")


--- Layout Menu
-- Generates a `awful.menu` with all layouts (names and icons).
-- @param layouts list of layouts the user wants to use.
-- @param args table with all relevant properties
-- @param args.align if set to right the icons will be arrange on the right side of the menu
-- @param args.width <i>(default theme.menu_width) </i> sets menu width
function layouts(Layouts, args)
    args = args or {}
    args.width = args.width or theme.menu_width
    local items = {}
    local theme = beautiful.get()
    for _, layout in ipairs(Layouts) do
        local layout_name = awful.layout.getname(layout)
        table.insert(items, { layout_name,
            function ()
                awful.layout.set(layout)
            end,
            theme["layout_" .. layout_name] })
    end
    local menu = awful.menu({ items = items, theme = { width = args.width } })
    if args.align == "right" then
        for _, item in ipairs(menu.items) do
            item.widget:reset()
            item.widget:set_left(item.label)
            item.widget:set_right(item.icon)
        end
    end
    return menu
end

--- Widget Toggler
-- Builds a useful little environment for widgets which are registered on vicious.
-- The function `toggle` turns all vicious widgets on or off.
-- The function `visible` returns if vicious widgets are off or on.
-- @return a table with this properties: widgets, toggle, visible
-- @usage add widgets to returning widgets list to enable the feature.
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

