  --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local mpris = { menu = {}, mt = {} }


local awful = require("awful")
local wibox = require("wibox")
local luadbus = require("lua-dbus")
local luampris = require("lua-mpris")
local beautiful = require("beautiful")


function mpris.menu.new(args)
    local menu = awful.menu({
        theme = { width = args.theme.height },
        layout = wibox.layout.flex.horizontal,
    })
    menu.layout.get_dir = function () return menu.layout.dir end
    menu.player = args.player
    local control = {
        prev = menu:add({
            new = mpris.menu.entry,
            icon = args.theme.previous,
            property = 'CanGoPrevious',
            cmd = function ()
                menu.player:previous()
            end,
        }),
        stop = menu:add({
            new = mpris.menu.entry,
            icon = args.theme.stopped,
            cmd = function ()
                menu.player:stop()
            end,
        }),
        play = menu:add({
            new = mpris.menu.entry,
            icon = args.theme.none,
            cmd = function ()
                menu.player:playpause()
            end,
        }),
        next = menu:add({
            new = mpris.menu.entry,
            icon = args.theme.next,
            property = 'CanGoNext',
            cmd = function ()
                menu.player:next()
            end,
        }),
    }
    menu.player:change('player', 'PlaybackStatus', function (status)
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
    end)
    return menu
end

function mpris.menu.entry(parent, args)
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
         image = args.theme.stopped,
          menu = menu,
    })
    ret.players = {}
    ret.menu    = menu
    ret.client  = luampris.Client:new()

    ret.entry = function (name, player)
        local icon = args.theme.none
        if args.lookup_icon then
            icon = args.lookup_icon(player.id) or icon
        end
        local submenu = mpris.menu.new({
            player = player,
            theme = args.theme,
        })
        local entry = ret.menu:add({ player.id, submenu.items, icon })
        ret.menu.child[#ret.menu.items] = submenu
        submenu.parent = ret.menu
        table.insert(ret.players, player)
    end

    ret.client:getPlayers(function (players)
        for name, player in pairs(players) do
            ret.entry(name, player)
        end
    end)

    local showmenu = menu.show
    ret.menu.show = function (...)
        local arguments = {...}
        ret.client:getPlayerNames(function (names)
            local playernames = {}
            for i = #ret.players,1,-1 do
                local player = ret.players[i]
                table.insert(playernames, player.name)
                if not haz(names, player.name) then
                    print("close player", player.name, i)
                    player:close()
                    ret.menu:delete(i)
                    table.remove(ret.players, i)
                end
            end
            for _, name in ipairs(names) do
                if not haz(playernames, name) then
                    local opts = ret.client
                    ret.entry(name, luampris.Client.Player:new(name, opts))
                end
            end
            showmenu(unpack(arguments))
        end)
    end

    return ret
end


function mpris.mt:__call(...)
    return new(...)
end

return setmetatable(mpris, mpris.mt)
