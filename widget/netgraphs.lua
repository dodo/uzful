--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local pairs = pairs
local table = table
local ipairs = ipairs
local vicious = require("vicious")
local widget = require("uzful.widget.util")
local getinfo = require("uzful.getinfo")
local setmetatable = setmetatable


module("uzful.widget.netgraphs")



local default_net_colors = { fg = {down = "#00FF00", up = "#FF0000"},
                             bg = {down = "#002000", up = "#200000"} }
--- fency Net Graphs for all network interfaces
-- To enable interface switch use: mynetgraphs.small.layout:connect_signal("button::release", mynetgraphs.switch)
-- @param args table with all relevant properties
-- @param args.default <i>(optional) </i> specify the selected interface
-- @param args.normal <i>(default: "$1") </i> display every interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.hightlight <i>(default: "$1") </i> display selected interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.small <i>(optional) </i> generates a small cpurgaph with all cpu usage combined when table given
-- @param args.small.scale <i>(optional when `args.small` given, default: "kb") </i> sets vicious network scale for small net graphs
-- @param args.small.interval <i>(needed when `args.small` given) </i> sets vicious update interval for small net graphs
-- @param args.small.width <i>(need when `args.small` given) </i> width of small cpu graph
-- @param args.small.height <i>(need when `args.small` given) </i> height of small cpu graph
-- @param args.small.fgcolor <i>(optional when `args.small` given) </i> foreground color of small cpu graph
-- @param args.small.bgcolor <i>(optional when `args.small` given) </i> background color of small cpu graph
-- @param args.big <i>(optional) </i> generates a big cpurgaph for each cpu core when table given
-- @param args.big.scale <i>(optional when `args.big` given, default: "mb") </i> sets vicious network scale for big net graphs
-- @param args.big.interval <i>(needed when `args.big` given) </i> sets vicious update interval for big net graphs
-- @param args.big.width <i>(need when `args.big` given) </i> width of a single big cpu graph
-- @param args.big.height <i>(need when `args.big` given) </i> height of a single big cpu graph
-- @param args.big.fgcolor <i>(optional when `args.big` given) </i> foreground color of big cpu graphs
-- @param args.big.bgcolor <i>(optional when `args.big` given) </i> background color of big cpu graphs
-- @param args.fgcolor <i>(optional) </i> default value of `args.small.fgcolor` and `args.big.fgcolor`
-- @param args.bgcolor <i>(optional) </i> default value of `args.small.bgcolor` and `args.big.bgcolor`
-- @return a table  with this properties: small <i>(when `args.small` given)</i> (with properties: layout, widgets, width, height), big <i>(wher `args.big` given)</i> (with properties: layout, widgets, width, height), switch <i>(when `args.big` and `args.small` are given)</i>
function new(args)
    local ret = {}
    for _, size in ipairs({"small", "big"}) do
        if args[size] then
            for _, typ in ipairs({"down", "up"}) do
                for ground, col in pairs(default_net_colors) do
                    args[size][typ .. '_' .. ground .. "color"] =
                        args[size][typ .. '_' .. ground .. "color"] or
                            args[typ .. '_' .. ground .. "color"]   or col[typ]
                end
            end
        end
    end

    local network_interfaces = getinfo.interfaces()
    local interface_cache = {}
    for k, v in ipairs(network_interfaces) do
        interface_cache[v] = k
    end

    local cur = network_interfaces[1]
    local i = 1
    while network_interfaces[i] do
      if args.default == network_interfaces[i] then
	cur = args.default
	break
      end
    end

    local small = nil
    local small_layout = {}
    if args.small then
        args.small.scale = args.small.scale or "kb"
        local small_widgets = {}
        local small_geometry={width=args.small.width,height=args.small.height/2}
        for _, interface in ipairs(network_interfaces) do
            local l = wibox.layout.fixed.vertical()
            for _, typ in ipairs({"down", "up"}) do
                local g = awful.widget.graph(small_geometry)
                widget.set_properties(g, {
                    border_color = nil,
                    color = args.small[typ .. '_fgcolor'],
                    background_color = args.small[typ .. '_bgcolor'] })
                vicious.register(g, vicious.widgets.net,
                    "${" ..interface.. " " ..typ.. "_" ..args.small.scale.. "}",
                    args.small.interval)
                table.insert(small_widgets, g)
                l:add(g)
            end
            small_layout[interface] = l
        end

        small = wibox.layout.fixed.horizontal()
        small:add(small_layout[cur])

        ret.small = {
            widgets = small_widgets,
            layout = small,
            height = args.small.height,
            width = args.small.widgth }
    end

    local if_text = function (interface)
        return (args.big and args.small and interface == cur) and
            vicious.helpers.format(args.highlight or "$1", { interface }) or
            vicious.helpers.format(args.normal    or "$1", { interface })
    end

    if args.big then
        args.big.scale = args.big.scale or "mb"
        local labels = {}

        ret.switch = function () end
        if args.small then
            ret.switch = function ()
                cur = network_interfaces[interface_cache[cur] %
                        #network_interfaces + 1]
                small:reset()
                small:add(small_layout[cur])
                for _, interface in ipairs(network_interfaces) do
                    labels[interface]:set_markup(if_text(interface))
                end
            end
        end

        local height = 0
        local big_widgets = {}
        local big = wibox.layout.fixed.vertical()
        local big_geometry = {width = args.big.width, height = args.big.height}
        for i, interface in ipairs(network_interfaces) do
            local label = wibox.widget.textbox()
            label:set_markup(if_text(interface))
            local _, h = label:fit(-1, -1)
            height = height + h
            big:add(label)
            labels[interface] = label
            for _, typ in ipairs({"down", "up"}) do
                local g = awful.widget.graph(big_geometry)
                widget.set_properties(g, {
                    border_color = nil,
                    color = args.big[typ .. '_fgcolor'],
                    background_color = args.big[typ .. '_bgcolor'] })
                vicious.register(g, vicious.widgets.net,
                    "${" ..interface.. " " ..typ.. "_" ..args.big.scale.. "}",
                    args.big.interval)
                height = height + big_geometry.height
                table.insert(big_widgets, g)
                big:add(g)
            end
        end
        ret.big = {
            widgets = big_widgets,
            layout = big,
            height = height,
            width = args.big.width}
    end
    return ret
end

setmetatable(_M, { __call = function (_, ...) return new(...) end })
