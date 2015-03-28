--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = require("uzful.menu.util")
local daemon = require("uzful.menu.daemon")

return {
    switch = require("uzful.menu.switch"),
    wallpaper = require("uzful.menu.wallpaper"),
    toggle_widgets = util.toggle_widgets,
    tag_info = util.tag_info,
    layouts = util.layouts,
    clients = daemon.clients,
    daemons = daemon,
    xrandr = util.xrandr,
    util = util,
}
