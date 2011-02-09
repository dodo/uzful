--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local Wibox = require("wibox")
local awful = require("awful")
local pairs = pairs
local table = table
local ipairs = ipairs
local vicious = require("vicious")
local getinfo = require("uzful.getinfo")


module("uzful.widget")


--- wibox helper
-- Just a wrapper for a nicer interface for `wibox`
-- @param args any wibox args plus screen, visible and widget
-- @param args.screen when given `wibox.screen` will be set
-- @param args.visible when given `wibox.visible` will be set
-- @param args.widget when given `wibox:set_widget` will be invoked
-- @return wibox object
function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    if args.widget then
        w:set_widget(args.widget)
    end
    return w
end

--- widget property setter
-- Any given property will invoke `widget:set_[property_key]([property_value])`.
-- @param widget the widget to be filled with properties
-- @param properties a table with the properties
-- @return the given widget
function set_properties(widget, properties)
    local fun = nil
    for name, property in pairs(properties) do
        fun = widget["set_" .. name]
        if fun then
            fun(widget, property)
        end
    end
    return widget
end

--- Progressbar and Image Glue
-- @param args table with all relevant properties
-- @param args.x <i>(optional) </i> progressbar x offset
-- @param args.y <i>(optional) </i> progressbar y offset
-- @param args.width progressbar width
-- @param args.width progressbar height
-- @param args.image <i>(optional) </i> image to be displayed
-- @return `wibox.widget.imagebox` with property progress with is a `awful.widget.progressbar`
function progressimage(args)
    local ret = Wibox.widget.imagebox()
    ret.progress = awful.widget.progressbar(args)

    ret.progress.x = args.x or 0
    ret.progress.y = args.y or 0
    if args.image then
        ret:set_image(args.image)
    end

    local draw_image = ret.draw
    local draw_progress = ret.progress.draw
    ret.draw = function (box, wibox, cr, width, height)
        draw_image(box, wibox, cr, width, height)
        width  = args.width  or width
        height = args.height or height
        cr:save()
        cr:translate(ret.progress.x, ret.progress.y)
        draw_progress(ret.progress, wibox, cr, width, height)
        cr:restore()
    end

    return ret
end


local default_cpu_colors = { fg = "#FFFFFF", bg = "#000000" }
--- fency CPU Graphs for all CPUs
-- @param args table with all relevant properties
-- @param args.label_height <i>(needed) </i>  the height for a single `wibox.widget.textbox`
-- @param args.load <i>(optional) </i> generates average load text when table given (only available when `args.big` is given)
-- @param args.load.text <i>(default "$1 $2 $3") </i> sets load text (replaces '$1', '$2' and '$3' with values) in big graphs layout
-- @param args.load.interval <i>(needed when `args.load` given) </i> sets vicious update interval for load text
-- @param args.small <i>(optional) </i> generates a small cpurgaph with all cpu usage combined when table given
-- @param args.small.interval <i>(needed when `args.small` given) </i> sets vicious update interval for small cpu graph
-- @param args.small.width <i>(need when `args.small` given) </i> width of small cpu graph
-- @param args.small.height <i>(need when `args.small` given) </i> height of small cpu graph
-- @param args.small.fgcolor <i>(optional when `args.small` given) </i> foreground color of small cpu graph
-- @param args.small.bgcolor <i>(optional when `args.small` given) </i> background color of small cpu graph
-- @param args.big <i>(optional) </i> generates a big cpurgaph for each cpu core when table given
-- @param args.big.interval <i>(needed when `args.big` given) </i> sets vicious update interval for big cpu graphs
-- @param args.big.width <i>(need when `args.big` given) </i> width of a single big cpu graph
-- @param args.big.height <i>(need when `args.big` given) </i> height of a single big cpu graph
-- @param args.big.fgcolor <i>(optional when `args.big` given) </i> foreground color of big cpu graphs
-- @param args.big.bgcolor <i>(optional when `args.big` given) </i> background color of big cpu graphs
-- @param args.fgcolor <i>(optional) </i> default value of `args.small.fgcolor` and `args.big.fgcolor`
-- @param args.bgcolor <i>(optional) </i> default value of `args.small.bgcolor` and `args.big.bgcolor`
-- @return a table  with this properties: small <i>(when `args.small` given)</i> (with properties: widget, width, height), big <i>(wher `args.big` given)</i> (with properties: layout, widgets, width, height), load <i>(when `args.load` given)</i>
function cpugraphs(args)
    local ret = {}
    for _, size in ipairs({"small", "big"}) do
        if args[size] then
            for ground, col in pairs(default_cpu_colors) do
                args[size][ground .. "color"] =
                    args[size][ground .. "color"] or
                          args[ground .. "color"] or col
            end
        end
    end

    local small = nil
    if args.small then
        small = awful.widget.graph(
            { width = args.small.width, height = args.small.height })
        set_properties(small, {
            border_color = nil,
            color = args.small.fgcolor,
            background_color = args.small.bgcolor })
        vicious.register(small, vicious.widgets.cpu, "$1", args.small.interval)
        ret.small = {
            widget = small,
            height = args.small.height,
            width = args.small.width }
    end


    if args.big then
        local height = 0
        local layout = Wibox.layout.fixed.vertical()
        if args.load then
            ret.load = Wibox.widget.textbox()
            vicious.register(ret.load, vicious.widgets.uptime,
                vicious.helpers.format(args.load.text or "$1 $2 $3",
                    {"$4", "$5", "$6"}), args.load.interval)
            layout:add(ret.load)
            height = height + args.label_height
        end

        local big = {}
        local big_geometry = {width = args.big.width, height = args.big.height}
        local cpucounter = getinfo.cpu_count()
        for i=1,cpucounter do
            big[i] = awful.widget.graph(big_geometry)
            set_properties(big[i], {
                border_color = nil,
                color = args.big.fgcolor,
                background_color = args.big.bgcolor })
            vicious.register(big[i], vicious.widgets.cpu, "$"..(i+1),
                args.big.interval)
            layout:add(big[i])
        end
        height = height + cpucounter * args.big.height
        ret.big = {
            layout = layout,
            widgets = big,
            height = height,
            width = args.big.width}
    end

    return ret
end

local default_net_colors = { fg = {down = "#00FF00", up = "#FF0000"},
                             bg = {down = "#002000", up = "#200000"} }
--- fency Net Graphs for all network interfaces
-- To enable interface switch use: mynetgraphs.small.layout:connect_signal("button::release", mynetgraphs.switch)
-- @param args table with all relevant properties
-- @param args.default <i>(optional) </i> specify the selected interface
-- @param args.normal <i>(default: "$1") </i> display every interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.hightlight <i>(default: "$1") </i> display selected interface name as text (replaces '$1' with interface name) in big graphs layout (only available when `args.big` is given)
-- @param args.label_height <i>(needed) </i>  the height for a single `wibox.widget.textbox`
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
function netgraphs(args)
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
    local cur = args.default or network_interfaces[1]

    local small = nil
    local small_layout = {}
    if args.small then
        args.small.scale = args.small.scale or "kb"
        local small_widgets = {}
        local small_geometry={width=args.small.width,height=args.small.height/2}
        for _, interface in ipairs(network_interfaces) do
            local l = Wibox.layout.fixed.vertical()
            for _, typ in ipairs({"down", "up"}) do
                local g = awful.widget.graph(small_geometry)
                set_properties(g, {
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

        small = Wibox.layout.fixed.horizontal()
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
        local big = Wibox.layout.fixed.vertical()
        local big_geometry = {width = args.big.width, height = args.big.height}
        for i, interface in ipairs(network_interfaces) do
            local label = Wibox.widget.textbox()
            label:set_markup(if_text(interface))
            height = height + args.label_height
            big:add(label)
            labels[interface] = label
            for _, typ in ipairs({"down", "up"}) do
                local g = awful.widget.graph(big_geometry)
                set_properties(g, {
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

