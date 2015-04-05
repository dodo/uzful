--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = require("uzful.widget.util")

return {
    repl = require("uzful.widget.repl"),
    span = require("uzful.widget.span"),
    wicd = require("uzful.widget.wicd"),
    mpris = require("uzful.widget.mpris"),
    syslog = require("uzful.widget.syslog"),
    battery = require("uzful.widget.battery"),
    calendar = require("uzful.widget.calendar"),
    titlebar = require("uzful.widget.titlebar"),
    netgraphs = require("uzful.widget.netgraphs"),
    cpugraphs = require("uzful.widget.cpugraphs"),
    bandgraph = require("uzful.widget.bandgraph"),
    temperature = require("uzful.widget.temperature"),
    progressimage = require("uzful.widget.progressimage"),
    set_properties = util.set_properties,
    hidable = util.hidable,
    infobox = util.infobox,
    wibox = util.wibox,
    util = util,
}

