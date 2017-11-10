--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = {}

local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")
local _, vicious = pcall(require, "vicious")
local uzful = { layout = { util = require("uzful.layout.util") } }
local capi = {
    screen = screen,
}


--- Layout Menu
-- Generates a `awful.menu` with all layouts (names and icons).
-- @param layouts list of layouts the user wants to use.
-- @param args table with all relevant properties
-- @param args.align if set to right the icons will be arrange on the right side of the menu
-- @param args.width <i>(default theme.menu_width) </i> sets menu width
function util.layouts(Layouts, args)
    args = args or {}
    args.width = args.width or theme.menu_width
    local items = {}
    local theme = beautiful.get()
    for _, layout in ipairs(Layouts) do
        local layout_name = awful.layout.getname(layout)
        table.insert(items, { layout_name,
            function ()
                awful.layout.set(layout)
            end,
            theme["layout_" .. layout_name] })
    end
    local menu = awful.menu({ items = items, theme = { width = args.width } })
    if args.align == "right" then
        for _, item in ipairs(menu.items) do
            item.widget:reset()
            item.widget:set_left(item.label)
            item.widget:set_right(item.icon)
        end
    end
    -- add this just for convenience
    menu.menu_switch = function ()
        local g = capi.screen[mouse.screen].geometry
        menu:toggle({
            coords = {
                x = g.x + g.width,
                y = g.y,
            },
            keygrabber = true,
        })
    end
    return menu
end

--- Widget Toggler
-- Builds a useful little environment for widgets which are registered on vicious.
-- The function `toggle` turns all vicious widgets on or off.
-- The function `visible` returns if vicious widgets are off or on.
-- @return a table with this properties: widgets, toggle, visible
-- @usage add widgets to returning widgets list to enable the feature.
function util.toggle_widgets()
    local widgets = {}
    local show = true
    local toggle = function ()
        show = not show
        if show then
            for _, widget in ipairs(widgets) do
                vicious.activate(widget)
            end
        else
            for _, widget in ipairs(widgets) do
                vicious.unregister(widget, true)
            end
        end
    end
    local visible = function () return show end
    return { widgets = widgets, toggle = toggle, visible = visible }
end

function util.tag_info(opts)
    opts = opts or {}
    local tagstatus = function ()
        local tag = awful.screen.focused().selected_tag
        naughty.notify({ text = string.format(
            "master width factor is now %d%%\nmaster count is now %d\ncolumn count is now %d",
            tag.master_width_factor * 100, tag.master_count, tag.column_count
        )})
    end
    return { theme = opts.theme,
        { "status", tagstatus },
        { "invert master width factor", function ()
            local tag = awful.screen.focused().selected_tag
            tag.master_width_factor = 1 - tag.master_width_factor
            naughty.notify({ text = string.format(
                "master width factor is now %d%%", tag.master_width_factor * 100
            )})
        end },
        { "swap column master", function ()
            local tag = awful.screen.focused().selected_tag
            tag.column_count, tag.master_count = tag.master_count, tag.column_count
            naughty.notify({ text = string.format(
                "master count is now %d\ncolumn count is now %d", tag.master_count, tag.column_count
            )})
        end },
        { "reset", function ()
            uzful.layout.util.reset(opts.default, nil, opts.layouts)
            tagstatus()
        end },
    }
end


function util.xrandr(screens, opts) -- ipairs(i, screen ids) pairs(screen id, screen name)
    opts = opts or {}
    opts.icons = opts.icons or beautiful.get()
    local localscreen = screens[1] -- first one is always the local screen
    local extscreen = 2 -- second one is default (cannot be first one)
    local menu_screen_text = function () return screens[screens[extscreen]] end
    local screensmenu = {
        { "same-as", string.format(
            "xrandr --output %s --auto --output %s --auto --same-as  %s",
            localscreen, screens[extscreen], localscreen),
            opts.icons.sameas },
        { "left-of", string.format(
            "xrandr --output %s --auto --output %s --auto --left-of  %s",
            localscreen, screens[extscreen], localscreen),
            opts.icons.leftof },
        { "right-of", string.format(
            "xrandr --output %s --auto --output %s --auto --right-of %s",
            localscreen, screens[extscreen], localscreen),
            opts.icons.rightof },
        { "above", string.format(
            "xrandr --output %s --auto --output %s --auto --above    %s",
            localscreen, screens[extscreen], localscreen),
            opts.icons.above },
        { "below", string.format(
            "xrandr --output %s --auto --output %s --auto --below    %s",
            localscreen, screens[extscreen], localscreen),
            opts.icons.below },
        { menu_screen_text(), function (m, menu)
            local prev = screens[extscreen]
            extscreen = extscreen + 1
            if extscreen > #screens then extscreen = 2 end
            m.label:set_text(menu_screen_text())
            for _, item in ipairs(menu.items) do
                if type(item.cmd) == 'string' then
                    item.cmd = string.gsub(item.cmd, prev, screens[extscreen])
                end
            end
            return true -- dont close menu
        end },
        menu_text = menu_screen_text,
        theme = opts and opts.theme or nil,
    }
    if capi.screen.count() > 1 then
        table.insert(screensmenu, 1, { "off", string.format(
            "xrandr --output %s --auto --output %s --off",
            localscreen, screens[extscreen]),
            opts.icons.off })
    end
    screensmenu.const = function ()
        local screen = {}
        for i, s in ipairs(screens) do
            if i == 1 then
                screen[s] = 1
            else
                screen[s] = 2
            end
        end
        return screen
    end
    return screensmenu
end

return util
