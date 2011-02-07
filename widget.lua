
local Wibox = require("wibox")
local awful = require("awful")
local pairs = pairs
local table = table
local ipairs = ipairs
local vicious = nil
local getinfo = require("uzful.getinfo")


module("uzful.widget")


function init(vcs)
    vicious = vcs
end


function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    if args.widget then
        w:set_widget(args.widget)
    end
    return w
end


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


function cpugraphs(args)
    local ret = {}
    for _, size in ipairs({"small", "big"}) do
        if args[size] then
            for _, ground in ipairs({"fg", "bg"}) do
                args[size][ground .. "color"] =
                    args[size][ground .. "color"] or
                          args[ground .. "color"]
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
        vicious.register(small, vicious.widgets.cpu, "$1", 1)
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
                vicious.helpers.format(args.load, {"$4", "$5", "$6"}), 20)
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
            vicious.register(big[i], vicious.widgets.cpu, "$"..(i+1), 1)
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


function netgraphs(args)
    local ret = {}
    for _, size in ipairs({"small", "big"}) do
        if args[size] then
            for _, typ in ipairs({"down", "up"}) do
                for _, ground in ipairs({"fg", "bg"}) do
                    args[size][typ .. '_' .. ground .. "color"] =
                        args[size][typ .. '_' .. ground .. "color"] or
                            args[typ .. '_' .. ground .. "color"]
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

    local small = nil
    local small_layout = {}
    if args.small then
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
                    "${" .. interface .. " " .. typ .. "_kb}", 2)
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
        local labels = {}
        if args.small then
            small:connect_signal("button::release", function ()
                cur = network_interfaces[interface_cache[cur] %
                     #network_interfaces + 1]
                small:reset()
                small:add(small_layout[cur])
                for _, interface in ipairs(network_interfaces) do
                    labels[interface]:set_markup(if_text(interface))
                end
            end)
        end

        local height = 0
        local big_widgets = {}
        local big = Wibox.layout.fixed.vertical()
        local big_geometry = { width = args.big.width, height = args.big.height }
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
                    "${" .. interface .. " " .. typ .. "_kb}", 2)
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

