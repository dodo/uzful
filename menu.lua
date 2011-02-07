--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local awful = require("awful")
local ipairs = ipairs
local table = table
local beautiful = nil
local vicious = nil

module("uzful.menu")

--- uzful.menu initiator
-- Needs to be executed once if `uztful.menu.layouts` and `uzful.menu.toggle_widgets` should work.
-- @param btfl the required beautiful library
-- @param vcs the required vicious library
function init(btfl, vcs)
    beautiful = btfl
    vicious = vcs
end

--- Layout Menu
-- Generates a `awful.menu` with all layouts (names and icons).
-- @param layouts list of layouts the user wants to use.
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

