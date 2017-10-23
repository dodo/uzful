--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local graph = { mt = {} }

local wibox = require("wibox")
local _, vicious = pcall(require, "vicious")
local _, helpers = pcall(require, "vicious.helpers")
local layout = require("uzful.layout.util")
local widget = require("uzful.widget.util")
local getinfo = require("uzful.getinfo")


local default_cpu_colors = { fg = "#FFFFFF", bg = "#000000" }
--- fency CPU Graphs for all CPUs
-- @param args table with all relevant properties
-- @param args.load <i>(optional) </i> generates average load text when table given (only available when `args.big` is given)
-- @param args.load.text <i>(default "$1 $2 $3") </i> sets load text (replaces '$1', '$2' and '$3' with values) in big graphs layout
-- @param args.load.font <i>(default beautiful.get_font()) </i> sets load font
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
local function new(args)
    local ret = {screen = args.screen or 1}
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
        small = wibox.widget.graph(args.small)
        widget.set_properties(small, {
            border_color = nil,
            color = args.small.fgcolor,
            background_color = args.small.bgcolor })
        vicious.register(small, vicious.widgets.cpu, "$1", args.small.interval)
        ret.small = {
            widget = small,
            layout = wibox.container.mirror(),
            height = args.small.height,
            width = args.small.width }
        ret.small.layout:set_reflection({ horizontal = (args.direction == "right")})
        ret.small.layout:set_widget(ret.small.widget)
    end


    if args.big then
        local height = 0
        if args.load then
            ret.load = wibox.widget.textbox()
            if args.load.font then  ret.load:set_font(args.load.font)  end
            vicious.register(ret.load, vicious.widgets.uptime,
                helpers.format(args.load.text or "$1 $2 $3",
                    {"$4", "$5", "$6"}), args.load.interval)
            local _, h = ret.load:get_preferred_size(ret.screen)
            height = height + h
        end

        local big = {}
        local cpucounter = getinfo.cpu_count()
        for i=1,cpucounter do
            table.insert(big, wibox.widget.graph(args.big))
            widget.set_properties(big[i], {
                border_color = nil,
                color = args.big.fgcolor,
                background_color = args.big.bgcolor })
            vicious.register(big[i], vicious.widgets.cpu, "$"..(i+1),
                args.big.interval)
        end
        height = height + cpucounter * args.big.height
        big.layout = wibox.layout.fixed.vertical
        ret.big = {
            layout = wibox.layout.fixed.vertical(),
            widgets = big,
            height = height,
            width = args.big.width}
        ret.big.layout:setup({
                ret.load,
                {
                    big,
                    reflection = {
                        horizontal = (args.direction == "right"),
                    },
                    layout = wibox.container.mirror,
                },
                layout = wibox.layout.fixed.vertical,
            })
    end

    return ret
end

function graph.mt:__call(...)
    return new(...)
end

return setmetatable(graph, graph.mt)

