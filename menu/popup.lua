--------------------------------------------------------------------------------
-- @author Damien Leone &lt;damien.leone@gmail.com&gt;
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @author dodo
-- @copyright 2008 Damien Leone, Julien Danjou
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local wibox = require("wibox")
local button = require("awful.button")
local util = require("awful.util")
local tags = require("awful.tag")
local beautiful = require("beautiful")
local setmetatable = setmetatable
local tonumber = tonumber
local string = string
local ipairs = ipairs
local pairs = pairs
local table = table
local type = type
local capi = {
    screen = screen,
    mouse = mouse,
    client = client,
    keygrabber = keygrabber,
    oocairo = oocairo }


module("uzful.menu.popup")


local cur_menu

--- Key bindings for menu navigation.
-- Keys are: up, down, exec, back, close. Value are table with a list of valid
-- keys for the action, i.e. menu_keys.up =  { "j", "k" } will bind 'j' and 'k'
-- key to up action. This is common to all created menu.
-- @class table
-- @name menu_keys
menu_keys = { up = { "Up" },
              down = { "Down" },
              exec = { "Return", "Right" },
              back = { "Left" },
              close = { "Escape" } }


local function load_theme(a, b)
    a = a or {}
    b = b or {}
    local ret = {}
    local fallback = beautiful.get()
    ret.border = a.border_color or b.menu_border_color or b.border_normal or
                 fallback.menu_border_color or fallback.border_normal
    ret.border_width= a.border_width or b.menu_border_width or b.border_width or
                      fallback.menu_border_width or fallback.border_width
    ret.fg_focus = a.fg_focus or b.menu_fg_focus or b.fg_focus or
                   fallback.menu_fg_focus or fallback.fg_focus
    ret.bg_focus = a.bg_focus or b.menu_bg_focus or b.bg_focus or
                   fallback.menu_bg_focus or fallback.bg_focus
    ret.fg_normal = a.fg_normal or b.menu_fg_normal or b.fg_normal or
                    fallback.menu_fg_normal or fallback.fg_normal
    ret.bg_normal = a.bg_normal or b.menu_bg_normal or b.bg_normal or
                    fallback.menu_bg_normal or fallback.bg_normal
    ret.submenu_icon= a.submenu_icon or b.menu_submenu_icon or b.submenu_icon or
                       fallback.menu_submenu_icon or fallback.submenu_icon
    ret.menu_height = a.height or b.menu_height or
                      fallback.menu_height or 16
    ret.menu_width = a.width or b.menu_width or
                     fallback.menu_width or 100
    return ret
end


local function set_coords(menu, screen_idx, m_coords)
    local s_geometry = capi.screen[screen_idx].workarea
    local screen_w = s_geometry.x + s_geometry.width
    local screen_h = s_geometry.y + s_geometry.height

    local i_h = menu.height + menu.theme.border_width
    local m_h = (i_h * #menu.items) + menu.theme.border_width

    if menu.parent then
        menu.width = menu.parent.width
        menu.height = menu.parent.height

        local p_w = i_h * (menu.num - 1)
        local m_w = menu.width - menu.theme.border_width

        menu.y = menu.parent.y + p_w + m_h > screen_h and
                 screen_h - m_h or menu.parent.y + p_w
        menu.x = menu.parent.x + m_w*2 > screen_w and
                 menu.parent.x - m_w or menu.parent.x + m_w
    else
        local m_w = menu.width
        if m_coords == nil then
            m_coords = capi.mouse.coords()
            m_coords.x = m_coords.x + 1
            m_coords.y = m_coords.y + 1
        end

        menu.y = m_coords.y < s_geometry.y and s_geometry.y or m_coords.y
        menu.x = m_coords.x < s_geometry.x and s_geometry.x or m_coords.x

        menu.y = menu.y + m_h > screen_h and screen_h - m_h or menu.y
        menu.x = menu.x + m_w > screen_w and screen_w - m_w or menu.x
    end
end


local function check_access_key(menu, key)
   for i, item in pairs(menu.items) do
      if item.akey == key then
          item_enter(menu, i)
          exec(menu, i)
          return
      end
   end
   if menu.parent then
      check_access_key(menu.parent, key)
   end
end


local function grabber(mod, key, event)
    if event == "release" then
       return true
    end

    local sel = cur_menu.sel or 0
    if util.table.hasitem(menu_keys.up, key) then
        local sel_new = sel-1 < 1 and #cur_menu.items or sel-1
        item_enter(cur_menu, sel_new)
    elseif util.table.hasitem(menu_keys.down, key) then
        local sel_new = sel+1 > #cur_menu.items and 1 or sel+1
        item_enter(cur_menu, sel_new)
    elseif sel > 0 and util.table.hasitem(menu_keys.exec, key) then
        exec(cur_menu, sel)
    elseif util.table.hasitem(menu_keys.back, key) then
        cur_menu:hide()
    elseif util.table.hasitem(menu_keys.close, key) then
        get_root(cur_menu):hide()
    else
        check_access_key(cur_menu, key)
    end

    return true
end


local function exec(menu, num, mouse_event)
    local cmd = menu.items[num].cmd
    if type(cmd) == "table" then
        if #cmd == 0 then
            return
        end
        if not menu.child[num] then
            menu.child[num] = new(cmd, menu, num)
        end

        if menu.active_child then
            menu.active_child:hide()
            menu.active_child = nil
        end
        menu.active_child = menu.child[num]
        menu.active_child:show()
    elseif type(cmd) == "string" then
        get_root(menu):hide()
        util.spawn(cmd)
    elseif type(cmd) == "function" then
        get_root(menu):hide()
        cmd(menu.items[num].returned_value)
    end
end


local function item_leave(menu, num)
    if num > 0 then
        menu.items[num].wibox:set_fg(menu.theme.fg_normal)
        menu.items[num].wibox:set_bg(menu.theme.bg_normal)
    end
end


local function item_enter(menu, num, mouse_event)
    if menu.sel == num then
        return
    elseif menu.sel then
        item_leave(menu, menu.sel)
    end

    menu.items[num].wibox:set_fg(menu.theme.fg_focus)
    menu.items[num].wibox:set_bg(menu.theme.bg_focus)
    menu.sel = num
    cur_menu = menu

    if menu.auto_expand and mouse_event then
        if menu.active_child then
            menu.active_child:hide()
            menu.active_child = nil
        end

        if type(menu.items[num].cmd) == "table" then
            exec(menu, num)
        end
    end
end


function clients(menu, args) -- FIXME crude api
    menu = menu or {}
    local cls = capi.client.get()
    local cls_t = {}
    for k, c in pairs(cls) do
        cls_t[#cls_t + 1] = {
            util.escape(c.name) or "",
            function ()
                if not c:isvisible() then
                    tags.viewmore(c:tags(), c.screen)
                end
                capi.client.focus = c
                c:raise()
            end,
            c.icon }
    end
    menu.items = cls_t

    local m = new(args, menu)
    m:show(args)
    return m
end


function get_root(menu)
    if menu.parent then
        return get_root(menu.parent)
    end
    return menu
end


function show(menu, args)
    args = args or {}
    local screen_index = capi.mouse.screen
    local keygrabber = args.keygrabber or false
    local coords = args.coords or nil
    set_coords(menu, screen_index, coords)
    for num, item in pairs(menu.items) do
        local wibox = item.wibox
        wibox.width = menu.width
        wibox.height = menu.height
        wibox.x = menu.x
        wibox.y = menu.y + (num - 1) * (menu.height + wibox.border_width)
        wibox.screen = screen_index
    end

    if menu.parent then
        menu.keygrabber = menu.parent.keygrabber
    elseif keygrabber ~= nil then
        menu.keygrabber = keygrabber
    else
        menu.keygrabber = false
    end

    if not cur_menu and menu.keygrabber then
        capi.keygrabber.run(grabber)
    end
    cur_menu = menu
end


function hide(menu)
    -- Remove items from screen
    for i = 1, #menu.items do
        item_leave(menu, i)
        menu.items[i].wibox.screen = nil
    end
    if menu.active_child then
        menu.active_child:hide()
        menu.active_child = nil
    end
    menu.sel = nil

    if cur_menu == menu then
        cur_menu = cur_menu.parent
    end
    if not cur_menu and menu.keygrabber then
        capi.keygrabber.stop()
    end
end


function toggle(menu, args)
    if menu.items[1] and menu.items[1].wibox.screen then
        menu:hide()
    else
        menu:show(args)
    end
end


function add(parent, item, num)
    if not item then return end
    local theme = load_theme(item.theme or {}, parent.theme)
    local box = wibox({
        fg = theme.fg_normal,
        bg = theme.bg_normal,
        border_color = theme.border,
        border_width = theme.border_width,
        type = "popup_menu" })
    -- Create bindings
    local bindings = util.table.join(
        button({}, 3, function () parent:hide() end),
        button({}, 1, function ()
            item_enter(parent, num)
            exec(parent, num)
        end ))
    box:buttons(bindings)
    box:connect_signal("mouse::enter", function ()
        item_enter(parent, num, true)
    end)
    -- Create the item label widget
    local label = wibox.widget.textbox()
    local key = ''
    label:set_markup(string.gsub(
        util.escape(item[1]), "&amp;(%w)",
        function (l)
            key = string.lower(l)
            return "<u>" .. l .. "</u>"
        end, 1))
    -- Set icon if needed
    local icon, iconbox
    local margin = wibox.layout.margin()
    margin:set_widget(label)
    if item[3] then
        icon = item[3]
        if type(icon) == "string" then
            if icon:find('.+%.png') then
                icon = capi.oocairo.image_surface_create_from_png(icon)
            else
                icon = nil -- FIXME little workaround for fuckup from xpm
            end
        end
    end
    if icon then
        local iw = icon:get_width()
        local ih = icon:get_height()
        if iw > parent.width or ih > parent.height then
            local w, h
            if ((parent.height / ih) * iw) > parent.width then
                w, h = parent.height, (parent.height / iw) * ih
            else
                w, h = (parent.height / ih) * iw, parent.height
            end
            -- We need to scale the image to size w x h
            local img = capi.oocairo.image_surface_create("argb32", w, h)
            local cr = capi.oocairo.context_create(img)
            cr:scale(w / iw, h / ih)
            cr:set_source(icon, 0, 0)
            cr:paint()
            icon = img
        end
        iconbox = wibox.widget.imagebox()
        iconbox:set_image(icon)
        margin:set_left(2)
    else
        margin:set_left(parent.height + 2)
    end
    -- Create the submenu icon widget
    local submenu_icon
    if type(item[2]) == "table" then
        submenu_icon = wibox.widget.imagebox()
        if theme.submenu_icon then
            submenu_icon:set_image(
                capi.oocairo.image_surface_create_from_png(
                theme.submenu_icon))
        end
        submenu_icon:buttons(bindings)
    end
    -- Add widgets to the wibox
    local left = wibox.layout.fixed.horizontal()
    if iconbox then
        left:add(iconbox)
    end
    -- This contains the label
    left:add(margin)

    local layout = wibox.layout.align.horizontal()
    layout:set_middle(left)
    if submenu_icon then
        layout:set_right(submenu_icon)
    end
    box:set_widget(layout)
    local w, h = label:fit(0, 0)
    box.height = h + 2
    box.ontop = true

    return {
        icon = iconbox,
        label = label,
        wibox = box,
        theme = theme,
        akey = key,
        cmd = item[2],
        returned_value = item[1] }
end


function new(args, parent, num)
    args = args or {}
    local theme = args.theme or {}
    local parent_theme = parent and parent.theme
    if theme == "reset" then
        theme = beautiful.get()
    end
    if theme.reset then
        parent_theme = beautiful.get()
    end
    local ret = {
        child = {},
        items = {},
        parent = parent,
        theme = load_theme(theme, parent_theme),
        num = num or 1 }

    if parent then
        ret.auto_expand = parent.auto_expand
    elseif args.auto_expand ~= nil then
        ret.auto_expand = args.auto_expand
    else
        ret.auto_expand = true
    end

    ret.height = parent and parent.height or ret.theme.menu_height
    if type(ret.height) ~= 'number' then ret.height = tonumber(ret.height) end
    ret.width  = parent and parent.width  or ret.theme.menu_width
    if type(ret.width)  ~= 'number' then ret.width  = tonumber(ret.width)  end

    ret.get_root = get_root
    ret.toggle = toggle
    ret.hide = hide
    ret.show = show
    ret.add = add

    -- Create items
    for i, v in ipairs(args) do
        table.insert(ret.items, ret:add(v, i))
    end
    if args.items then
        for i, v in ipairs(args.items) do
            table.insert(ret.items, ret:add(v, i))
        end
    end

    if #ret.items > 0 and ret.height < ret.items[1].wibox.height then
        ret.height = ret.items[1].wibox.height
    end

    return ret
end

setmetatable(_M, { __call = function (_, ...) return new(...) end })
