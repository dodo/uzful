 --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local repl = { mt = {} }

local awful = require("awful")
local common = require("awful.widget.common")
local beautiful = require("beautiful")
local wibox = require("wibox")
local util = require("uzful.util")
local capi = {
    client = client,
    mouse = mouse,
    screen = screen
}

-- Options section

repl.max_lines = 64

--- Specifies the geometry of the menubar. This is a table with the keys
-- x, y, width and height. Missing values are replaced via the screen's
-- geometry. However, missing height is replaced by the font size.
repl.geometry = { width = nil, height = nil, x = nil, y = nil }

--- Allows user to specify custom parameters for prompt.run function
-- (like colors).
repl.prompt_args = {prompt = "> "}

-- Private section
local instance = { prompt = nil, widget = nil, wibox = nil }

-- Create the menubar wibox and widgets.
local function initialize()
    instance.prepend = ''
    instance.text = ""
    instance.lines = 0
    instance.wibox = wibox({})
    instance.widget = wibox.widget.textbox()
    instance.widget:set_valign('bottom')
    instance.wibox.ontop = true
    instance.prompt = awful.widget.prompt()
    local layout = wibox.layout.fixed.vertical()
    layout:add(instance.widget)
    layout:add(instance.prompt)
    instance.wibox:set_widget(layout)
end

function repl.show(scr, args)
    if type(scr) == 'table' then scr, args = nil, scr end
    args = args or {}
    if not instance.wibox then
        initialize()
    elseif instance.wibox.visible and not args.reset then -- Menu already shown, exit
        return
    end
    util.table.default(args, repl.prompt_args)

    -- Set position and size
    scr = scr or args.screen or capi.mouse.screen or 1
    local function update()
        local scrgeom = capi.screen[scr].workarea
        local geometry = repl.geometry
        local _height = geometry.height or beautiful.get_font_height() * 1.5
        _height = _height + instance.lines * beautiful.get_font_height()

        instance.widget:set_text(instance.text)
        instance.wibox:geometry({x = geometry.x or scrgeom.x,
                                y = geometry.y or scrgeom.y,
                                height = _height,
                                width = geometry.width or scrgeom.width})
    end
    instance.update = update
    update()

    local abort = true
    awful.prompt.run(args, instance.prompt.widget,
        function(s) -- exe_callback
            if s == 8 or s == 'quit' or s == 'exit' or s == ':q' then
                abort = true
            elseif s == 'clear' or s == 'reset' then
                abort = false
                instance.text = ""
                instance.lines = 0
                instance.prepend = ''
            else
                abort = false
                repl.write(args.prompt .. s .. '\n')
                repl.run(s)
            end
        end,
        function (text, cur_pos, ncomp) -- completion_callback
            local keywords = {}
            for k,_ in pairs(_G) do
                table.insert(keywords, k)
            end
            return awful.completion.generic(text, cur_pos, ncomp, keywords)
        end,
        awful.util.getdir("cache") .. "/history_repl",
        nil, function () -- done_callback
            if abort then
                repl.enabled = false
                repl.hide()
            else
                args.reset = true
                repl.show(src, args)
                args.reset = false
            end
        end
    )
    instance.wibox.visible = true
    repl.enabled = true
end

--- Hide the repl.
function repl.hide()
    instance.wibox.visible = false
end

function repl.write(s)
    if not repl.enabled then return end
    local lines, neednewline = {}, false
    local text =instance.text .. instance.prepend .. s
    instance.prepend = ''
    for line in util.string.gsplit(text, "\n") do lines[#lines+1] = line end
    while #lines > repl.max_lines do table.remove(lines, 1) end
    while lines[#lines] == "" do table.remove(lines) neednewline = true end
    if #lines == 0 then
        instance.lines = 0
        instance.text = ""
    else
        if neednewline then instance.prepend = '\n' end
        instance.lines = #lines
        instance.text = table.concat(lines, "\n")
        instance.update()
    end
end

function repl.run(cmd)
    local mockio, text = {}, ""
    function mockio.read() end
    function mockio.flush()
        repl.write(text)
        text = ""
    end
    function mockio.write(s)
        text = text .. tostring(s)
    end
    local function mockprint(...)
        local s = {}
        for _, x in ipairs({...}) do
            s[#s+1] = tostring(x)
        end
        mockio.write(table.concat(s, '\t') .. '\n')
        mockio.flush()
    end
    local env = setmetatable({ io = mockio, print = mockprint }, { __index = _G })
    local exe, err = loadstring(cmd:gsub('^%s*=', 'return '), '[awesome repl]')
    if err then
        repl.write(err .. '\n')
    else
        setfenv(exe, env)
        local ok, val = pcall(exe)
        if not ok then
            err = val
            repl.write(err .. '\n')
        elseif val then
            repl.write(tostring(val) .. '\n')
        end
    end
end

return setmetatable(repl, repl.mt)
