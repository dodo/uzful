

local type = type
local pairs = pairs

module("uzful.layout")


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

