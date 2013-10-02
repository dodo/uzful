--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local tag = require("awful.tag")


local function strips_group(p, orientation, group, offset, fact)
    orientation = orientation or "south"

    -- this handles are different orientations
    local height = "height"
    local width = "width"
    local x = "x"
    local y = "y"
    if orientation == "east" then
        height = "width"
        width = "height"
        x = "y"
        y = "x"
    end

    local cls = p.clients
    local wa = p.workarea
    local size =  math.min(wa[width] * fact, wa[width] - offset)
    local small = math.max(0, size / (group.last - group.first + 1))
    for i = group.first,group.last do local c = cls[i]
        local g = {}
        g[width]  = small      - c.border_width * 2
        g[height] = wa[height] - c.border_width * 2
        g[x] = wa[x] + offset
        g[y] = wa[y]
        c:geometry(g)

        offset = offset + g[width]
    end
    return offset
end


local function strips(p, orientation)
    local cls = p.clients
    if #cls == 0 then return end

    local t = tag.selected(p.screen)
    local nmaster = math.min(tag.getnmaster(t), #cls)
    local nother = math.max(#cls - nmaster,0)

    local mwfact = tag.getmwfact(t)

    local o = strips_group(p, orientation, {first=1, last=nmaster}, 0, mwfact)
    strips_group(p, orientation, {first=nmaster+1, last=nmaster+nother}, o, 1)
end


--- Vertical strips layout.
-- @param screen The screen to arrange.
local columns = {}
columns.name = "columns"
function columns.arrange(p)
    return strips(p, "south")
end


--- Horizontal strips layout.
-- @param screen The screen to arrange.
local rows = {}
rows.name = "rows"
function rows.arrange(p)
    return strips(p, "east")
end


return {
    columns = columns,
    rows = rows,
}