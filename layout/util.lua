--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = {}

local screen = require("awful.screen")
local layout = require("awful.layout")

function util.reset(default, tag, layouts)
    tag = tag or screen.focused().selected_tag
    tag.master_width_factor = 0.5
    tag.master_count = 1
    tag.column_count = 1
    util.set(default, tag, layouts)
end

function util.set(l, t, layouts)
    l = util.get(l, layouts)
    if l then layout.set(l, t) end
end

function util.get(l, layouts)
    if type(l) == 'number' then
        return (layouts or layout.layouts)[l]
    elseif type(l) == 'string' then
        return util.get_by_name(l, layouts)
    elseif type(l) == 'table' then
        return l
    end
end

function util.get_by_name(name, layouts)
    for _, lt in ipairs(layouts or layout.layouts) do
        if layout.getname(lt) == name then
            return lt
        end
    end
end


return util
