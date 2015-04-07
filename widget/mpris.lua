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


function mpris.menu.new(args)
    local menu = awful.menu({
        theme = { width = args.theme.height },
        layout = wibox.layout.flex.horizontal,
    })
    menu.layout.get_dir = function () return menu.layout.dir end
    menu.player = args.player
    local control = {
        prev = menu:add({
            new = mpris.menu.item,
            icon = args.theme.previous,
            property = 'CanGoPrevious',
            cmd = function ()
                menu.player:previous()
            end,
        }),
        stop = menu:add({
            new = mpris.menu.item,
            icon = args.theme.stopped,
            cmd = function ()
                menu.player:stop()
            end,
        }),
        play = menu:add({
            new = mpris.menu.item,
            icon = args.theme.none,
            cmd = function ()
                menu.player:playpause()
            end,
        }),
        next = menu:add({
            new = mpris.menu.item,
            icon = args.theme.next,
            property = 'CanGoNext',
            cmd = function ()
                menu.player:next()
            end,
        }),
    }
    menu.player:change('player', 'PlaybackStatus', function (status)
        menu.player.playerbackstatus = tostring(status):lower()
        control.prev.recheck()
        control.next.recheck()
        if status == 'Playing' then
            control.stop.flags.control = true
            control.play.flags.icon = args.theme.stopped
            control.stop.update()
            menu.player:get('player', 'CanPause', function (pause)
                control.play.flags.control = pause
                control.play.flags.icon = args.theme.paused
                control.play.update()
            end)
        elseif status == 'Paused' then
            control.stop.flags.control = true
            control.play.flags.icon = args.theme.stopped
            control.stop.update()
            menu.player:get('player', 'CanPlay', function (play)
                control.play.flags.control = play
                control.play.flags.icon = args.theme.playing
                control.play.update()
            end)
        elseif status == 'Stopped' then
            control.stop.flags.control = false
            control.stop.update()
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
    ret.icon:set_image(args.icon or args.theme.none)
    ret.flags.icon = args.icon
    ret.update = function ()
        if ret.flags.control and ret.flags.icon then
            ret.icon:set_image(ret.flags.icon)
        else
            ret.icon:set_image(args.theme.none)
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
            parent.player:change('player', args.property, ret.update_property)
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
    local menu = awful.menu()
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
            icon = args.lookup_icon(player.id) or icon
        end
        local submenu = mpris.menu.new({
            player = player,
            theme = args.theme,
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
        ret.client:onPlayer(function (player)
            if player.closed then
                if ret.last_player == player then
                    ret.select()
                end
                if player.menu then
                    ret.menu:delete(player.menu)
                    if #ret.menu.items == 0 then
                        ret.hide()
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
                        ret.select()
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
