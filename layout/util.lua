--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local type = type
local pairs = pairs

module("uzful.layout.util")

--- Builds a layout from a table tree
-- When inserted a function it returns the result without parameters.
-- When given table has property layout it will instancate it add all list items from the table to it.
-- Whe given table has properties it will try to invoke the `set_[key]` function of the layout.
-- @param tree the table describing the layout (can be recursive)
-- @return a layout or the result of the given function or just the input
function build(tree)
    if type(tree) == "function" then
        return tree()
    end
    if tree.layout then
        local value = nil
        local layout = tree.layout()
        for i=1,#tree do
            if tree[i] then
                value = build(tree[i])
                if value then layout:add(value) end
            end
        end
        for key, value in pairs(tree) do
            if type(key) == "string" and layout["set_" .. key] then
                value = build(value)
                if value then layout["set_" .. key](layout, value) end
            end
        end
        return layout
    end
    return tree
end

