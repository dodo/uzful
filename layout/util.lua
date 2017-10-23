--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = {}

local screen = require("awful.screen")


function util.reset()
    local tag = screen.focused().selected_tag
    tag.master_width_factor = 0.5
    tag.master_count = 1
    tag.column_count = 1
end

return util
