
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

