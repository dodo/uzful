  --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local mpris = { menu = {}, mt = {} }


local awful = require("awful")
local wibox = require("wibox")
local _, luadbus = pcall(require, "lua-dbus")
local _, luampris = pcall(require, "lua-mpris")
local beautiful = require("beautiful")
local uzful = { widget = require("uzful.widget.util") }
local capi = { timer = (type(timer) == 'table' and timer or require("gears.timer")) }


function mpris.menu.new(args)
    local menu = awful.menu({
        theme = { width = args.theme.height },
        layout = wibox.layout.fixed.horizontal,
    })
    menu.player = args.player
    menu.control = {
        prev = menu:add({
            new = mpris.menu.item,
            icon = args.theme.previous,
            noicon = args.theme.none,
            property = 'CanGoPrevious',
            cmd = function ()
                menu.player:previous()
            end,
        }),
        stop = menu:add({
            new = mpris.menu.item,
            icon = args.theme.stopped,
            noicon = args.theme.none,
            cmd = function ()
                menu.player:stop()
            end,
        }),
        play = menu:add({
            new = mpris.menu.item,
            icon = args.theme.none,
            noicon = args.theme.none,
            cmd = function ()
                menu.player:playpause()
            end,
        }),
        next = menu:add({
            new = mpris.menu.item,
            icon = args.theme.next,
            noicon = args.theme.none,
            property = 'CanGoNext',
            cmd = function ()
                menu.player:next()
            end,
        }),
        fullscreen = menu:add({
            new = mpris.menu.button,
            icon = 'sticky',
            active = false,
            property = 'CanSetFullscreen',
            cmd = function ()
                menu.player:set('media', 'Fullscreen',
                    not menu.control.fullscreen.flags.value)
            end,
        }),
        raise = menu:add({
            new = mpris.menu.button,
            icon = 'ontop',
            active = false,
            property = 'CanRaise',
            cmd = function ()
                menu.player:raise()
            end,
        }),
        progress = menu:add({
            new = mpris.menu.progressbar,
            timeout = 1, -- secound
            width = 42,
        }),
        label = menu:add({
            new = mpris.menu.label,
            text = "",
        }),
        close = menu:add({
            new = mpris.menu.button,
            icon = 'close',
            active = false,
            property = 'CanQuit',
            cmd = function ()
                menu.player:quit()
            end,
        }),
    }
    local control = menu.control
    control.progress.hide()
--         control.label.widget:set_text("mps")
    menu.player:change('media', 'DesktopEntry', function (icon_name)
        if icon_name and menu.player.menu and menu.player.menu.icon then
            local icon = args.theme.none
            if args.lookup_icon then
                icon = args.lookup_icon(icon_name) or icon
            end
            menu.player.menu.icon:set_image(icon)
        end
    end)
    menu.player:change('media', 'Identity', function (identity)
        if identity and menu.player.menu and menu.player.menu.label then
            menu.player.menu.label:set_text(identity)
        end
    end)
    menu.player:change('media', 'Fullscreen', function (isfullscreen)
        if type(isfullscreen) == 'boolean' then
            control.fullscreen.flags.value = isfullscreen
            control.fullscreen.update()
        end
    end)
    menu.player:change('player', 'PlaybackStatus', function (status)
        local was = menu.player.playerbackstatus
        menu.player.playerbackstatus = tostring(status):lower()
        control.prev.recheck()
        control.next.recheck()
        if status == 'Playing' then
            control.stop.flags.control = true
            control.play.flags.icon = args.theme.stopped
            control.stop.update()
            if was == 'stopped' then
                control.progress.set_position(0)
            end
            menu.player:get('player', 'Position', function (pos)
                control.progress.set_position(pos)
                control.progress.play()
            end)
            menu.player:get('player', 'CanPause', function (pause)
                control.play.flags.control = pause
                control.play.flags.icon = args.theme.paused
                control.play.update()
            end)
        elseif status == 'Paused' then
            control.stop.flags.control = true
            control.play.flags.icon = args.theme.stopped
            control.stop.update()
            control.progress.pause()
            menu.player:get('player', 'CanPlay', function (play)
                control.play.flags.control = play
                control.play.flags.icon = args.theme.playing
                control.play.update()
            end)
        elseif status == 'Stopped' then
            control.stop.flags.control = false
            control.stop.update()
            control.progress.pause()
            control.progress.hide()
            menu.player:get('player', 'CanPlay', function (play)
                control.play.flags.control = play
                control.play.flags.icon = args.theme.playing
                control.play.update()
            end)
        end
        -- show last action of all players
        if menu.parent and menu.parent.launcher then
            menu.parent.launcher.select(menu.player.id)
        end
    end)
    menu.player:change('player', 'Position', function (pos)
        if not pos then return end
        control.progress.set_position(pos)
    end)
    menu.player:change('player', 'Metadata', function (meta)
        meta = meta or {}
        if meta['xesam:title'] then
            control.label.widget:set_text(meta['xesam:title'])
        else
            control.label.widget:set_text("")
        end
        if meta['mpris:length'] then
            control.progress.set_length(meta['mpris:length'])
            control.progress.show()
        else
            control.progress.hide()
        end
    end)
    menu.items.cmd = function ()
        if menu.parent and menu.parent.launcher then
            menu.parent.launcher.select(menu.player.id)
        end
        return true -- dont close menu
    end
    return menu
end

function mpris.menu.item(parent, args)
    args = args or {}
    local ret = { akey = '', flags = {} }
    ret.icon = wibox.widget.imagebox()
    ret.widget = ret.icon
    ret.icon:set_image(args.icon)
    ret.flags.icon = args.icon
    ret.update = function ()
        if ret.flags.control and ret.flags.icon then
            ret.icon:set_image(ret.flags.icon)
        else
            ret.icon:set_image(args.noicon)
        end
    end
    parent.player:change('player', 'CanControl', function (control)
        ret.flags.control = control
        ret.update()
    end)
    if args.property then
        ret.update_property = function (prop)
            ret.flags[args.property] = prop
            ret.flags.control = args.test(prop)
            ret.update()
        end
        args.test = args.test or function (x) return x end
        parent.player:change('player', args.property, ret.update_property)
        ret.recheck = function ()
            parent.player:get('player', args.property, ret.update_property)
        end
    end
    if args.cmd then
        ret.cmd = function (...)
            if ret.flags.control then
                args.cmd(...)
            end
            return true -- dont close menu
        end
    end
    return ret
end

function mpris.menu.button(parent, args)
    args = args or {}
    local ret  = { akey = '', flags = { active = args.active, value = args.value } }
    ret.icon   = uzful.widget.hidable(wibox.widget.imagebox())
    ret.width  = parent.theme.width
    ret.height = parent.theme.height
    ret.widget = ret.icon
    ret.update = function()
        if not ret.flags.active then
            ret.width = 0
            ret.icon.hide()
            return
        end
        ret.width = parent.theme.width
        local img = ret.flags.value and "active" or "inactive"
        img = beautiful["titlebar_" .. args.icon .. "_button_normal_" .. img] or
              beautiful["titlebar_" .. args.icon .. "_button_" .. img] or
              beautiful["titlebar_" .. args.icon .. "_button_normal"] or
              beautiful["titlebar_" .. args.icon .. "_button"]
        if img then ret.icon:set_image(img) end
        ret.icon.show()
    end
    if args.active == false then
        ret.width = 0
        ret.icon.hide()
    end
    parent.player:change('media', args.property, function (active)
        ret.flags.active = active
        ret.update()
    end)
    if args.cmd then
        ret.cmd = function (...)
            args.cmd(...)
            return true -- dont close menu
        end
    end
    return ret
end

function mpris.menu.progressbar(parent, args)
    args = args or {}
    local ret = {
        akey = '', flags = {},
        position = 0, length = 0,
        height = parent.theme.height,
        width = args.width,
    }
    ret.timer = capi.timer({ timeout = args.timeout })
    ret.progress = awful.widget.progressbar({
        height = ret.height,
        width  = ret.width,
    })
    ret.progress:set_background_color('#000000') -- FIXME
    ret.progress:set_color(parent.theme.fg_normal)
    ret.widget = ret.progress
    ret.update = false
    ret.show = function ()
        ret.width = args.width
        ret.progress:set_width(ret.width)
        if ret.update then
            ret.timer:again()
        end
    end
    ret.hide = function ()
        ret.width = 0
        ret.progress:set_width(ret.width)
        if ret.update then
            if ret.timer.data.source_id ~= nil then
                ret.timer:stop()
            end
        end
    end
    ret.play = function ()
        if ret.width > 0 and not ret.update then
            ret.timer:start()
        end
        ret.update = true
    end
    ret.pause = function ()
        if ret.width > 0 and ret.update then
            ret.timer:stop()
        end
        ret.update = false
    end
    ret.set_position = function (pos)
        ret.position =  tonumber(pos or ret.position) or 0
        ret.progress:set_value(ret.position)
    end
    ret.set_length = function (len)
        ret.length =        len or ret.length
        ret.progress:set_max_value(ret.length)
        ret.progress:set_value(ret.position)
    end
    ret.timer:connect_signal("timeout", function ()
        ret.set_position(ret.position + args.timeout * 1e6) -- microseconds
    end)
    return ret
end

function mpris.menu.label(parent, args)
    args = args or {}
    local ret = { akey = '', flags = {} }
    ret.widget = wibox.widget.textbox()
    ret.label = ret.widget
    ret.label:set_font(parent.theme.font)
    local set_text = ret.label.set_text
    ret.label.set_text = function (...)
        set_text(...)
        ret.width, ret.height = ret.label:fit(-1, parent.theme.height)
        ret.width = math.min(1000, ret.width)
        if parent.wibox.visible then
            parent:show({ coords = parent })
        end
    end
    ret.label:set_text(args.text)
    return ret
end


local function haz(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

local function new(args)
    args = args or {}
    args.theme = args.theme or beautiful.get()
    local menu = awful.menu({ theme = args.theme })
    local  ret = awful.widget.launcher({
         image = args.theme.none,
          menu = menu,
    })
    ret = uzful.widget.hidable(ret)
    ret.menu    = menu
    ret.client  = luampris.Client:new()
    menu.launcher = ret

    ret.item = function (name, player)
        ret.show()
        local icon = args.theme.none
        if args.lookup_icon then
            icon = args.lookup_icon(player.id and player.id:match('([^.]+)')) or icon
        end
        local submenu = mpris.menu.new({
            player = player,
            theme = args.theme,
            lookup_icon = args.lookup_icon,
        })
        local item = ret.menu:add({ player.id, submenu.items, icon, theme = { submenu = "○" } })
        ret.menu.child[#ret.menu.items] = submenu
        submenu.parent = ret.menu
        player.submenu = submenu
        player.menu = item
    end

    ret.client:getPlayers(function (players)
        for name, player in pairs(players) do
            ret.item(name, player)
        end
    end)

    if args.realtime ~= false then
        ret.hide()
        ret.menu:hide()
        ret.client:onPlayer(function (player)
            if player.closed then
                if ret.last_player == player then
                    local _, pl = next(ret.client.players or {})
                    ret.select(pl and pl.id)
                end
                if player.menu then
                    ret.menu:delete(player.menu)
                    if #ret.menu.items == 0 then
                        ret.hide()
                        ret.menu:hide()
                    end
                end
            elseif not player.menu then
                ret.item(player.name, player)
            end
        end)
    else
        local showmenu = menu.show
        ret.menu.show = function (...)
            local arguments = {...}
            ret.client:updatePlayers(function (added, removed, unchanged)
                for _, player in ipairs(removed) do
                    if ret.last_player == player then
                        local _, pl = next(ret.client.players or {})
                        ret.select(pl and pl.id)
                    end
                    if player.menu then
                        ret.menu:delete(player.menu)
                    end
                end
                for _, player in ipairs(added) do
                    ret.item(player.name, player)
                end
                return showmenu(unpack(arguments))
            end)
        end
    end

    -- add lua controls

    ret.select = function (name)
        if ret.last_player and ret.last_player.menu then
            ret.last_player.menu.sep:set_text("○")
        end
        if name and ret.client.players then
            for _, player in pairs(ret.client.players) do
                if player.id == name then
                    local image = args.theme[player.playerbackstatus]
                    ret:set_image(image or args.theme.none)
                    ret.last_player = player
                    if player.menu then
                        player.menu.sep:set_text("●")
                    end
                    return player
                end
            end
        end
        ret:set_image(args.theme.none)
        ret.last_player = nil
    end
    ret.previous = function ()
        if ret.last_player then
            ret.last_player:previous()
        end
    end
    ret.stop = function ()
        if ret.last_player then
            ret.last_player:stop()
        end
    end
    ret.playpause = function ()
        if ret.last_player then
            ret.last_player:playpause()
        end
    end
    ret.next = function ()
        if ret.last_player then
            ret.last_player:next()
        end
    end

    return ret
end


function mpris.mt:__call(...)
    return new(...)
end

return setmetatable(mpris, mpris.mt)
