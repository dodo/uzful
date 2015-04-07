--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local graph = { mt = {} }

local awful = require("awful")
local wibox = require("wibox")
local _, vicious = pcall(require, "vicious")
local _, helpers = pcall(require, "vicious.helpers")
local uzful = { widget = { bandgraph = require("uzful.widget.bandgraph") } }
local widget = require("uzful.widget.util")
local layout = require("uzful.layout.util")
local getinfo = require("uzful.getinfo")
local beautiful = require("beautiful")


local default_net_colors = { fg = {down = "#00FF0099", up = "#FF000099"},
                             mg = {down = "#00FF0011", up = "#FF000011"},
                             bg = {down = "#002000",   up = "#200000"} }
--- fency Net Graphs for all network interfaces
-- To enable interface switch use: mynetgraphs.small.layout:connect_signal("button::release", mynetgraphs.switch)
-- @param args table with all relevant properties
-- @param args.default <i>(optional) </i> specify the selected interface (name or number)
-- @param args.normal <i>(default: "$1") </i> display every interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.hightlight <i>(default: "$1") </i> display selected interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.font <i>(default: beautiful.get_font()) </i> sets interface name text' font in big graphs layout (only available when `args.big` is given)
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
-- @param args.theme <i>(optional) </i> defaults to beautiful.get()
-- @return a table  with this properties: small <i>(when `args.small` given)</i> (with properties: layout, widgets, width, height), big <i>(wher `args.big` given)</i> (with properties: layout, widgets, width, height), switch <i>(when `args.big` and `args.small` are given)</i>
local function new(args)
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

    local interface_cache = {}
    local network_interfaces = args.interfaces or getinfo.interfaces()
    local cur = type(args.default) == "number" and args.default or 1
    cur = network_interfaces[cur]
    for k, v in ipairs(network_interfaces) do
        interface_cache[v] = k
        if v == args.default then
            cur = v
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
                local g = uzful.widget.bandgraph(small_geometry)
                widget.set_properties(g, {
                    border_color = nil,
                    color = args.small[typ .. '_fgcolor'],
                    band_color = args.small[typ .. '_mgcolor'],
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
            layout = layout.build({
                widget = small,
                reflection = {
                    vertical = (args.direction == "right"),
                },
                layout = wibox.layout.mirror,
            }),
            height = args.small.height,
            width = args.small.widgth }
    end

    local if_text = function (interface)
        return (args.big and args.small and interface == cur) and
            helpers.format(args.highlight or "$1", { interface }) or
            helpers.format(args.normal    or "$1", { interface })
    end
    local set_color = function (bg, interface)
        local theme = args.theme or beautiful.get()
        if interface == cur then
            bg:set_fg(theme.fg_focus)
            bg:set_bg(theme.bg_focus)
        else
            bg:set_fg(theme.fg_normal)
            bg:set_bg(theme.bg_normal)
        end
    end

    if args.big then
        args.big.scale = args.big.scale or "mb"
        local big = wibox.layout.fixed.vertical()
        local big_geometry = {width = args.big.width, height = args.big.height}
        local active = {}
        local big_widgets = {}
        local backgrounds = {}
        local big_graphs = {}
        local labels = {}

        ret.switch = function () end
        ret.toggle = function () end
        ret.update_active = function () end
        if args.small then
            ret.toggle = function () ret.switch() end
            ret.switch = function (newcur)
                if not newcur and #active == 0 then return end
                cur = newcur or active[interface_cache[cur] %
                        #active + 1]
                small:reset()
                small:add(small_layout[cur])
                for _, interface in ipairs(network_interfaces) do
                    set_color(backgrounds[interface], interface)
                    labels[interface]:set_markup(if_text(interface))
                end
            end
            ret.update_active = function (newcur)
                local netdata = vicious.widgets.net()
--                 for k,v in pairs(netdata) do print(k,v) end
                local height = 0
                active = {}
                big:reset()
                for i, interface in ipairs(network_interfaces) do
                    if netdata["{"..interface.." carrier}"] == 1 then
                        table.insert(active, interface)
                        local _, h = labels[interface]:fit(-1, -1)
                        height = height + h + big_geometry.height * 2
                        big:add(labels[interface])
                        big:add(big_graphs[interface])
                        vicious.activate(big_widgets[(i - 1) * 2 + 1])
                        vicious.activate(big_widgets[(i - 1) * 2 + 2])
                    else
                        local _, h = labels[interface]:fit(-1, -1)
                        height = height + h
                        big:add(labels[interface])
                        vicious.unregister(big_widgets[(i - 1) * 2 + 1], true)
                        vicious.unregister(big_widgets[(i - 1) * 2 + 2], true)
                    end
                end
                if newcur then ret.switch(newcur) end
                ret.big.height = height
            end
        end

        local height = 0
        for i, interface in ipairs(network_interfaces) do
            table.insert(active, interface)
            local label = wibox.widget.textbox()
            label:set_markup(if_text(interface))
            if args.font then  label:set_font(args.font)  end
            local _, h = label:fit(-1, -1)
            height = height + h
            labels[interface] = label
            local background = wibox.widget.background()
            background:set_widget(label)
            set_color(background, interface)
            big:add(background)
            backgrounds[interface] = background
            local mirror = wibox.layout.mirror()
            mirror:set_reflection({ vertical = (args.direction == "right") })
            big_graphs[interface] = mirror
            local graphs = wibox.layout.fixed.vertical()
            for _, typ in ipairs({"down", "up"}) do
                local g = uzful.widget.bandgraph(big_geometry)
                widget.set_properties(g, {
                    border_color = nil,
                    color = args.big[typ .. '_fgcolor'],
                    band_color = args.big[typ .. '_mgcolor'],
                    background_color = args.big[typ .. '_bgcolor'] })
                vicious.register(g, vicious.widgets.net,
                    "${" ..interface.. " " ..typ.. "_" ..args.big.scale.. "}",
                    args.big.interval)
                height = height + big_geometry.height
                table.insert(big_widgets, g)
                graphs:add(g)
            end
            mirror:set_widget(graphs)
            big:add(mirror)
        end
        ret.big = {
            widgets = big_widgets,
            layout = big,
            height = height,
            width = args.big.width}
    end
    return ret
end


function graph.mt:__call(...)
    return new(...)
end

return setmetatable(graph, graph.mt)
