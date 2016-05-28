---------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 dodo
-- @release v3.4-797-g2752173
---------------------------------------------------------------------------

local syslog = { mt = {} }

local widget = require("wibox.widget")
local beautiful = require("beautiful")
local uzful = {
    util = require("uzful.util"),
    widget = require("uzful.widget.util"),
}
local capi = {
    screen = screen,
}

local data = setmetatable({}, { __mode = "k" })


function syslog.get_log(box)
    return data[box].log
end

function syslog.get_text(box)
    return data[box].text
end


local function new(args)
    args = args or {}
    args.screen = args.screen or 1
    args.position = args.position or "bottom"
    if args.visible == nil then args.visible = true end
    if args.ontop == nil then args.ontop = false end

    -- luarocks install inotify INOTIFY_INCDIR=/usr/include/x86_64-linux-gnu
    local lognotify = require("lognotify")
    local log = lognotify({
        logs = args.logs or {},
        interval = args.interval or 0.1,
    })
    local sllines = args.lines or 32
    local text = ""

    local syslogtext = widget.textbox()
    if args.font then syslogtext:set_font(args.font) end
    syslogtext:set_valign(args.position)
    syslogtext:set_text(" \n")

    log.notify = function (self, name, file, diff)
        text = string.format("%s\n%s", text, diff)
        text = uzful.util.lineswrap(text, sllines)
        syslogtext:set_text(text)
    end
    log:start()

    local theme = beautiful.get()
    local box = uzful.widget.infobox({ screen = args.screen,
        width = capi.screen[args.screen].geometry.width,
        height = sllines * beautiful.get_font_height(theme.font),
        position = args.position, align = args.align or "left",
        visible = args.visible, ontop = args.ontop,
        widget = syslogtext,
        bg = args.bg or "#00000000",
        fg = args.fg })
    -- store reference somewhere
    data[box] = { log = log, text = syslogtext }
    return box
end


function syslog.mt:__call(...)
    return new(...)
end

return setmetatable(syslog, syslog.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
