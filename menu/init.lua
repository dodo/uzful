--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = require("uzful.menu.util")
local daemon = require("uzful.menu.daemon")

return {
    wallpaper = require("uzful.menu.wallpaper"),
    toggle_widgets = util.toggle_widgets,
    layouts = util.layouts,
    clients = daemon.clients,
    daemons = daemon,
    util = util,
}
