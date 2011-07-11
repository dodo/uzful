--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local ipairs = ipairs

module("uzful.layout.suit.strips")

local function strips(p, orientation)
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

    local wa = p.workarea
    local cls = p.clients
    if #cls == 0 then return end
    local small = {
        width = wa.width / #cls,
        height = wa.height / #cls }

    for i, c in ipairs(cls) do
        local g = {}
        g[width]  = small[width] - c.border_width * 2
        g[height] = wa[height]   - c.border_width * 2

        g[x] = wa[x] + (i-1) * g[width]
        g[y] = wa[y]

        c:geometry(g)
    end
end

--- Vertical strips layout.
-- @param screen The screen to arrange.
columns = {}
columns.name = "columns"
function columns.arrange(p)
    return strips(p, "south")
end

--- Horizontal strips layout.
-- @param screen The screen to arrange.
rows = {}
rows.name = "rows"
function rows.arrange(p)
    return strips(p, "east")
end
