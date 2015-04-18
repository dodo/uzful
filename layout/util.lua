--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = {}

local tag = require("awful.tag")
local uzful = { util = require("uzful.util") }


--- Builds a layout from a table tree
-- When inserted a function it returns the result without parameters.
-- When given table has property layout it will instancate it add all list items from the table to it.
-- Whe given table has properties it will try to invoke the `set_[key]` function of the layout.
-- @param tree the table describing the layout (can be recursive)
-- @return a layout or the result of the given function or just the input
function util.build(tree)
    if not tree then return end
    if type(tree) == "function" then
        return tree()
    end
    if uzful.util.iscallable(tree.layout) then
        local value = nil
        local layout = tree.layout()
        for i=1,#tree do
            value = util.build(tree[i])
            if value then layout:add(value) end
        end
        for key, value in pairs(tree) do
            if type(key) == "string" and layout["set_" .. key] then
                value = util.build(value)
                if value then layout["set_" .. key](layout, value) end
            end
        end
        return layout
    end
    return tree
end

function util.reset()
    local sel = tag.selected()
    tag.setproperty(sel, "mwfact", 0.5)
    tag.setproperty(sel, "nmaster", 1 )
    tag.setproperty(sel, "ncol", 1 )
end

return util
