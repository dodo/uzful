--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local ipairs = ipairs

module("uzful.layout.suit.strips")

local function strips(p, orientation)
    local wa = p.workarea
    local cls = p.clients
    if #cls == 0 then return end
    local small = {
        width = wa.width / #cls,
        height = wa.height / #cls }

    for i, c in ipairs(cls) do
        local g = {}
        if  orientation == "south" then
            g.width  = small.width
            g.height = wa.height

            g.x = wa.x + (i-1) * g.width
            g.y = wa.y
        else
            g.width  = wa.width
            g.height = small.height

            g.x = wa.x
            g.y = wa.y + (i-1) * g.height
        end

        g.width = g.width - c.border_width * 2
        g.height = g.height - c.border_width * 2
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
