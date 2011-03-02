--------------------------------------------------------------------------------
-- @author Damien Leone &lt;damien.leone@gmail.com&gt;
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @author dodo
-- @copyright 2008, 2011 Damien Leone, Julien Danjou, dodo
-- @release @AWESOME_VERSION@
--------------------------------------------------------------------------------

local wibox = require("wibox")
local button = require("awful.button")
local util = require("awful.util")
local tags = require("awful.tag")
local beautiful = require("beautiful")
local object = require("gears.object")
local setmetatable = setmetatable
local tonumber = tonumber
local string = string
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local print = print
local table = table
local type = type
local math = math
local capi = {
    timer = timer,
    screen = screen,
    mouse = mouse,
    client = client,
    keygrabber = keygrabber,
    oocairo = oocairo }


module("uzful.menu.rewrite")


table.update = function (t, set)
    for k, v in pairs(set) do
        t[k] = v
    end
    return t
end


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
    if a.reset      then b = fallback end
    if a == "reset" then a = fallback end
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
    ret.height = a.height or b.menu_height or b.height or
                 fallback.menu_height or 16
    ret.width = a.width or b.menu_width or b.width or
                fallback.menu_width or 100
    return ret
end


local function set_coords(menu, screen_idx, m_coords)
    local s_geometry = capi.screen[screen_idx].workarea
    local screen_w = s_geometry.x + s_geometry.width
    local screen_h = s_geometry.y + s_geometry.height

    menu.width = menu.wibox.width
    menu.height = menu.wibox.height

    menu.x = menu.wibox.x
    menu.y = menu.wibox.y

    if menu.parent then


        -- FIXME this values (w,h) should be obtained from layout
        local h, w = 0, menu.parent.width
        local num = util.table.hasitem(menu.parent.child, menu) - 1
        if num then
            for i = 0, num do
                local item = menu.parent.items[i]
                if item then
                    w = math.max(item.width, w)
                    h = h + item.height
                end
            end
        end
        w = w + menu.parent.theme.border_width * 2

        menu.y = menu.parent.y + h + menu.height > screen_h and
                 screen_h - menu.height or menu.parent.y + h
        menu.x = menu.parent.x + w + menu.width > screen_w and
                 menu.parent.x - menu.width or menu.parent.x + w
    else
        if m_coords == nil then
            m_coords = capi.mouse.coords()
            m_coords.x = m_coords.x + 1
            m_coords.y = m_coords.y + 1
        end
        menu.y = m_coords.y < s_geometry.y and s_geometry.y or m_coords.y
        menu.x = m_coords.x < s_geometry.x and s_geometry.x or m_coords.x

        menu.y = menu.y + menu.height > screen_h and
                 screen_h - menu.height or menu.y
        menu.x = menu.x + menu.width  > screen_w and
                 screen_w - menu.width  or menu.x
    end

    menu.wibox.x = menu.x
    menu.wibox.y = menu.y
end


local function set_size(menu) -- FIXME it would be better to get it from the layout
    local width, height = 0, 0
    for _, item in ipairs(menu.items) do
        width = math.max(width, item.width)
        height = height + item.height
    end
    menu.wibox.height = height
    menu.wibox.width = width
    menu.height = height
    menu.width = width
end


local function check_access_key(menu, key)
   for i, item in ipairs(menu.items) do
      if item.akey == key then
            menu:item_enter(i)
            menu:exec(i)
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
        cur_menu:item_enter(sel_new)
    elseif util.table.hasitem(menu_keys.down, key) then
        local sel_new = sel+1 > #cur_menu.items and 1 or sel+1
        cur_menu:item_enter(sel_new)
    elseif sel > 0 and util.table.hasitem(menu_keys.exec, key) then
        cur_menu:exec(sel)
    elseif util.table.hasitem(menu_keys.back, key) then
        cur_menu:hide()
    elseif util.table.hasitem(menu_keys.close, key) then
        get_root(cur_menu):hide()
    else
        check_access_key(cur_menu, key)
    end

    return true
end


function exec(menu, num, mouse_event)
    local item = menu.items[num]
    if not item then return end
    local cmd = item.cmd
    if type(cmd) == "table" then
        if #cmd == 0 then
            return
        end
        if not menu.child[num] then
            menu.child[num] = new(cmd, menu)
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
        local visible, action = cmd(item, menu)
        if not visible then
            get_root(menu):hide()
        else
            menu:update()
            if menu.items[num] then
                menu:item_enter(num, mouse_event)
            end
        end
        if action and type(action) == "function" then
            action()
        end
    end
end

function item_enter(menu, num, mouse_event)
    local item = menu.items[num]
    if num == nil or menu.sel == num or not item then
        return
    elseif menu.sel then
        menu:item_leave(menu.sel)
    end
    --print("sel", num, menu.sel, item.theme.bg_focus)
    item._background:set_fg(item.theme.fg_focus)
    item._background:set_bg(item.theme.bg_focus)
    cur_menu = menu
    menu.sel = num

    if menu.auto_expand and mouse_event then
        if menu.active_child then
            menu.active_child:hide()
            menu.active_child = nil
        end

        if type(item.cmd) == "table" then
            menu:exec(num)
        end
    end
end


function item_leave(menu, num)
    --print("leave", num)
    local item = menu.items[num]
    if item then
        item._background:set_fg(item.theme.fg_normal)
        item._background:set_bg(item.theme.bg_normal)
    end
end


--- Show a menu.
-- @param menu The menu to show.
-- @param args.keygrabber A boolean enabling or not the keyboard navigation.
-- @param args.coords Menu position defaulting to mouse.coords()
function show(menu, args)
    args = args or {}
    local coords = args.coords or nil
    local screen_index = capi.mouse.screen
    local keygrabber = args.keygrabber or false

    menu.wibox.screen = screen_index
    set_size(menu)
    set_coords(menu, screen_index, coords)

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
    menu.wibox.visible = true
end

--- Hide a menu popup.
-- @param menu The menu to hide.
function hide(menu)
    -- Remove items from screen
    for i = 1, #menu.items do
        menu:item_leave(i)
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
    menu.wibox.visible = false
end

--- Toggle menu visibility.
-- @param menu The menu to show if it's hidden, or to hide if it's shown.
-- @param args.keygrabber A boolean enabling or not the keyboard navigation.
-- @param args.coords Menu position {x,y}
function toggle(menu, args)
    if menu.wibox.visible then
        menu:hide()
    else
        menu:show(args)
    end
end

--- Update menu content
-- @param menu The mnenu to update.
function update(menu)
    if menu.wibox.visible then
        menu:show({
            keygrabber = menu.keygrabber,
            coords = { x = menu.x, y = menu.y } })
    end
end


--- Get the elder parent so for example when you kill
-- it, it will destroy the whole family.
-- @param menu The sub menu of the menu family.
function get_root(menu)
    return menu.parent and get_root(menu.parent) or menu
end

--- Add a new menu entry
-- @param menu The parent menu
-- @param args The item params
-- @param args.new (Default: awful.menu.entry) The menu entry constructor
-- @param args.theme (Optional) The menu entry theme
-- @param args.* params needed for the menu entry constructor
-- @param index (Optional) the index where the new entry will inserted
function add(menu, args, index)
    if not args then return end
    local theme = load_theme(args.theme or {}, menu.theme)
    args.theme = theme
    args.new = args.new or entry
    local success, item = pcall(args.new, menu, args)
    if not success then
        print("Error while creating menu entry: " .. item)
        return
    end
    if not item.widget then
        print("Error while checking menu entry: no property widget found.")
        return
    end
    item.parent = menu
    item.theme = item.theme or theme
    item.width = item.width or theme.width
    item.height = item.height or theme.height
    wibox.widget.base.check_widget(item.widget)
    item._background = wibox.widget.background()
    item._background:set_widget(item.widget)
    item._background:set_fg(item.theme.fg_normal)
    item._background:set_bg(item.theme.bg_normal)


    -- Create bindings
    item._background:buttons(util.table.join(
        button({}, 3, function () menu:hide() end),
        button({}, 1, function ()
            local num = util.table.hasitem(menu.items, item)
            menu:item_enter(num)
            menu:exec(num)
        end )))


    item._mouse = function ()
        local num = util.table.hasitem(menu.items, item)
        menu:item_enter(num, true)
    end
    item.widget:connect_signal("mouse::enter", item._mouse)

    if index then
        menu.layout:reset()
        table.insert(menu.items, index, item)
        for _, i in ipairs(menu.items) do
            menu.layout:add(i._background)
        end
    else
        table.insert(menu.items, item)
        menu.layout:add(item._background)
    end
    return item
end

-- Delete menu entry at given position
-- @param menu The menu
-- @param num The position in the table of the menu entry to be deleted; can be also the menu entry itself
function delete(menu, num)
    if type(num) == "table" then
        num = util.table.hasitem(menu.items, num)
    end
    local item = menu.items[num]
    if not item then return end
    item.widget:disconnect_signal("mouse::enter", item._mouse)
    item.widget.screen = nil
    table.remove(menu.items, num)
    if menu.sel == num then
        menu:item_leave(menu.sel)
        menu.sel = nil
    end
    if menu.child[num] then
         menu.child[num]:hide()
        if menu.active_child == menu.child[num] then
            menu.active_child = nil
        end
        table.remove(menu.child, num)
    end
end

--------------------------------------------------------------------------------

--- Build a popup menu with running clients and shows it.
-- @param menu Menu table, see new() function for more informations
-- @param args.keygrabber A boolean enabling or not the keyboard navigation.
-- @return The menu.
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

--------------------------------------------------------------------------------

--- Default awful.menu.entry constructor
-- @param parent The parent menu
-- @param args the item params
-- @return table with 'widget', 'cmd', 'akey' and all the properties the user wants to change
function entry(parent, args)
    args = args or {}
    args.text = args[1] or args.text or ""
    args.cmd = args[2] or args.cmd
    args.icon = args[3] or args.icon
    local ret = {}
    -- Create the item label widget
    local label = wibox.widget.textbox()
    local key = ''
    label:set_markup(string.gsub(
        util.escape(args.text), "&amp;(%w)",
        function (l)
            key = string.lower(l)
            return "<u>" .. l .. "</u>"
        end, 1))
    -- Set icon if needed
    local icon, iconbox
    local margin = wibox.layout.margin()
    margin:set_widget(label)
    if args.icon then
        icon = args.icon
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
        if iw > args.theme.width or ih > args.theme.height then
            local w, h
            if ((args.theme.height / ih) * iw) > args.theme.width then
                w, h = args.theme.height, (args.theme.height / iw) * ih
            else
                w, h = (args.theme.height / ih) * iw, args.theme.height
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
        margin:set_left(args.theme.height + 2)
    end
    -- Create the submenu icon widget
    local submenu_icon
    if type(args.cmd) == "table" then
        submenu_icon = wibox.widget.imagebox()
        if args.theme.submenu_icon then
            submenu_icon:set_image(
                capi.oocairo.image_surface_create_from_png(
                args.theme.submenu_icon))
        end
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

    return table.update(ret, {
        label = label,
        icon = iconbox,
        widget = layout,
        cmd = args.cmd,
        akey = key,
    })
end

--------------------------------------------------------------------------------

--- Create a menu popup.
-- @param args Table containing the menu informations.<br/>
-- <ul>
-- <li> Key items: Table containing the displayed items. Each element is a table by default (when element 'new' is awful.menu.entry) containing: item name, triggered action, submenu table or function, item icon (optional). </li>
-- <li> Keys theme.[fg|bg]_[focus|normal], theme.border_color, theme.border_width, theme.submenu_icon, theme.height and theme.width override the default display for your menu and/or of your menu entry, each of them are optional. </li>
-- <li> Key auto_expand controls the submenu auto expand behaviour by setting it to true (default) or false. </li>
-- </ul>
-- @param parent Specify the parent menu if we want to open a submenu, this value should never be set by the user.
-- @usage The following function builds, and shows a menu of clients that match
-- a particular rule. Bound to a key, it can for example be used to select from
-- dozens of terminals open on several tags. With the use of
-- <code>match_any</code> instead of <code>match</code>, menu of clients with
-- different classes can also be build.
--
-- <p><code>
--                     function terminal_menu ()                           <br/>
-- &nbsp;                terms = {}                                        <br/>
-- &nbsp;                for i, c in pairs(client.get()) do                <br/>
-- &nbsp;&nbsp;            if awful.rules.match(c, {class = "URxvt"}) then <br/>
-- &nbsp;&nbsp;&nbsp;        terms[i] =                                    <br/>
-- &nbsp;&nbsp;&nbsp;          {c.name,                                    <br/>
-- &nbsp;&nbsp;&nbsp;           function()                                 <br/>
-- &nbsp;&nbsp;&nbsp;&nbsp;       awful.tag.viewonly(c:tags()[1])          <br/>
-- &nbsp;&nbsp;&nbsp;&nbsp;       client.focus = c                         <br/>
-- &nbsp;&nbsp;&nbsp;           end,                                       <br/>
-- &nbsp;&nbsp;&nbsp;           c.icon                                     <br/>
-- &nbsp;&nbsp;&nbsp;          }                                           <br/>
-- &nbsp;&nbsp;            end                                             <br/>
-- &nbsp;                end                                               <br/>
-- &nbsp;                m = awful.menu(terms)                             <br/>
-- &nbsp;                m:show({keygrabber=true})                         <br/>
-- &nbsp;                return m                                          <br/>
--                     end                                                 <br/>
--</code></p>
function new(args, parent)
    args = args or {}
    args.layout = args.layout or wibox.layout.flex.vertical
    local menu = table.update(object(), {
        item_enter = item_enter,
        item_leave = item_leave,
        get_root = get_root,
        delete = delete,
        update = update,
        toggle = toggle,
        hide = hide,
        show = show,
        exec = exec,
        add = add,
        child = {},
        items = {},
        parent = parent,
        layout = args.layout(),
        theme = load_theme(args.theme or {}, parent and parent.theme) })

    if parent then
        menu.auto_expand = parent.auto_expand
    elseif args.auto_expand ~= nil then
        menu.auto_expand = args.auto_expand
    else
        menu.auto_expand = true
    end

    -- Create items
    for i, v in ipairs(args) do  menu:add(v)  end
    if args.items then
        for i, v in pairs(args.items) do  menu:add(v)  end
    end

    menu.wibox = wibox({
        ontop = true,
        fg = menu.theme.fg_normal,
        bg = menu.theme.bg_normal,
        border_color = menu.theme.border,
        border_width = menu.theme.border_width,
        type = "popup_menu" })
    menu.wibox.visible = false
    menu.wibox:set_widget(menu.layout)
    set_size(menu)

    menu.x = menu.wibox.x
    menu.y = menu.wibox.y
    return menu
end

setmetatable(_M, { __call = function (_, ...) return new(...) end })
