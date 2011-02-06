

local awful = require("awful")
local ipairs = ipairs
local table = table
local beautiful = nil

module("uzful.menu")


function init(btfl)
    beautiful = btfl
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