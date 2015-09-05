 --------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local battery = { mt = {} }

local wibox = require("wibox")
local _, vicious = pcall(require, "vicious")
local beautiful = require("beautiful")
local kdeconnect = require("uzful.ext.kdeconnect")
local uzful = {
    util = require("uzful.util"),
    widget = {
        progressimage = require("uzful.widget.progressimage"),
        set_properties = require("uzful.widget.util").set_properties,
        hidable = require("uzful.widget.util").hidable,
    },
    notifications = require("uzful.notifications.util"),
}

function battery.set_text(bat, percentage)
    if bat.text then
        bat.text:set_text(string.format("%s%s%s%d%%",
            bat.name or '',
            bat.name and '  ' or '',
            bat.charging and '+' or '−',
            percentage * 100
        ))
    end
end

function battery.set_value(bat, percentage)
    battery.set_text(bat, percentage)
    bat.widget.progress:set_value(percentage)
    bat.critical:set_value(percentage)
    bat.ticks:set_value(percentage)
end


-- uzful.widget.battery.phone({
--     x = 3, y = 5, width = 2, height = 5,
--     theme = theme.phone, font = "ProggyTinyTT 12",
-- })
function battery.phone(args)
    args = args or {}
    args.threshold = args.threshold or {}
    args.theme = args.theme or beautiful.get()
    args.color = args.color or "#FFFFFF"
    args.normal = args.normal or "#000000"
    args.charge = args.charge or "#6E9931"
    args.critical = args.critical or "#8C0000"
    local ret = {
        id = args.id,
        charging = false,
        set_text = battery.set_text,
        set_value = battery.set_value,
    }
    -- Battery Text
    if args.text ~= false then
        ret.text = wibox.widget.textbox()
        if args.font then ret.text:set_font(args.font) end
        ret.text:set_text("?")
    end
    -- phone status via kdeconnect
    ret.widget = uzful.widget.hidable(uzful.widget.progressimage({
        image = args.theme.battery,
        x = args.x, y = args.y, width = args.width, height = args.height }))
    uzful.widget.set_properties(ret.widget.progress, {
        ticks = true, ticks_gap = 1,  ticks_size = 1,
        vertical = true, background_color = args.normal,
        border_color = nil, color = args.color })
    -- test if kdeconnect is on
    kdeconnect.call('device', 'forceOnNetworkChange', function (err)
        if err then
            ret.widget.hide()
        end
    end)
    ret.ticks = uzful.util.threshold(args.threshold.full or 0.9,
        function () uzful.widget.set_properties(ret.widget.progress, { ticks = false }) end,
        function () uzful.widget.set_properties(ret.widget.progress, { ticks = true  }) end)
    ret.critical = uzful.notifications.critical({
        title = "Critical Phone Battery Charge",
        threshold = args.threshold.low or 0.2,
        empty = args.threshold.empty or 0.1,
        silent = (args.notifications == false),
        widget = ret.widget.progress,
        normal = args.normal, critical = args.critical,
        on = function ()
            if ret.charging then
                return args.charge
            end
        end,
        off = function ()
            if ret.charging then
                return args.charge
            end
        end,
        text = function (percentage)
            return string.format("%s%sonly %d%% remaining.",
                ret.name or "", ret.name and " has " or "", percentage)
        end,
    })
    local function change_state(state)
        ret.charging = (state == true)
        ret.widget.progress:set_background_color(ret.charging and args.charge or args.normal)
        ret:set_text(ret.ticks:get_value())
    end
    local device = kdeconnect.device(args.id)
    device.on('battery', 'stateChanged', change_state)
    device.on('battery', 'chargeChanged', function (charge)
        ret:set_value((charge or 100) / 100)
        ret.widget.show()
    end)

    if device.id then
        -- get initial state
        device.call('battery', 'charge', function (charge)
            ret:set_value((tonumber(charge) or 100) / 100)
        end)
        device.call('battery', 'isCharging', change_state)
        -- update reachability
        ret.update = function ()
            kdeconnect.property.get('device', 'name', function (name)
                ret.name = name
                ret:set_text(ret.ticks:get_value())
            end, device.path)
            device.call('device', 'isPaired', function (paired)
                if paired ~= true then
                    ret.widget.hide()
                    return
                end
                device.call('device', 'isReachable', function (reachable)
                    if reachable == true then
                        ret.widget.show()
                    else -- false or error
                        ret.widget.hide()
                    end
                end)
            end)
        end
        ret.update()
        device.on('device', 'reachableStatusChanged', ret.update)
        device.on('device', 'pairingSuccessful', ret.update)
        device.on('device', 'unpaired', ret.update)
    else
        ret.update = function () end -- noop
    end
    return ret
end

-- uzful.widget.battery({
--     bat = 'BAT0', ac = 'AC',
--     x = 3, y = 4, width = 3, height = 7,
--     theme = theme, font = "ProggyTinyTT 12",
-- })
local function new(args)
    args = args or {}
    args.threshold = args.threshold or {}
    args.theme = args.theme or beautiful.get()
    if not args.ac then error("args.ac is missing!") end
    if not args.bat then error("args.bat is missing!") end
    args.color = args.color or "#FFFFFF"
    args.normal = args.normal or "#000000"
    args.charge = args.charge or "#6E9931"
    args.hidden = args.hidden or "#00000000"
    args.critical = args.critical or "#8C0000"
    args.interval = args.interval or 60
    local ret = {
        set_value = battery.set_value,
        timer = args.timer,
    }
    local dock_online = ((uzful.util.scan.sysfs({
        property = {"modalias", "platform:dock"},
        sysattr = {"type", "dock_station"},
        subsystem = "platform",
    }).sysattrs[1] or {}).docked == "1")
    local power_supply_online = ((uzful.util.scan.sysfs({
        property = {"power_supply_name", args.ac},
        subsystem = "power_supply",
    }).properties[1] or {}).power_supply_online == "1")
    local battery_online = (uzful.util.scan.sysfs({
        property = {"power_supply_name", args.bat},
        subsystem = "power_supply"}).length > 0)
    ret.widget = uzful.widget.progressimage({
        image = battery_online and (dock_online and args.theme.dock or args.theme.battery) or args.theme.nobattery,
        x = args.x, y = args.y, width = args.width, height = args.height })
    uzful.widget.set_properties(ret.widget.progress, {
        ticks = true, ticks_gap = 1,  ticks_size = 1,
        vertical = true, background_color = power_supply_online and args.charge or args.normal,
        border_color = nil, color = args.color })

   ret.ticks = uzful.util.threshold(args.threshold.full or 0.9,
        function (val) uzful.widget.set_properties(ret.widget.progress, { ticks = false }) end,
        function (val) uzful.widget.set_properties(ret.widget.progress, { ticks = true  }) end)
    vicious.register(ret.ticks,           vicious.widgets.bat, "$2", args.interval, args.bat)
    vicious.register(ret.widget.progress, vicious.widgets.bat, "$2", args.interval, args.bat)
    -- Battery Text
    if args.text ~= false then
        ret.text = wibox.widget.textbox()
        if args.font then ret.text:set_font(args.font) end
        ret.text:set_text("?")
        vicious.register(ret.text, vicious.widgets.bat,
            '$1$3 $2%', args.interval, args.bat)
    end
    -- notifications
    ret.critical = uzful.notifications.critical({
        threshold = args.threshold.low or 0.2,
        empty = args.threshold.empty or 0.1,
        widget = ret.widget.progress,
        normal = args.normal, critical = args.critical,
        silent = (args.notifications == false),
        on = function ()
            if not battery_online then
                return args.hidden
            elseif power_supply_online then
                return args.charge
            end
        end,
        off = function ()
            if not battery_online then
                return args.hidden
            elseif power_supply_online then
                return args.charge
            end
        end })
    vicious.register(ret.critical, vicious.widgets.bat, "$2", args.interval, args.bat)
    --
    ret.listeners = {ret.widget.progress, ret.ticks, ret.critical}
    if ret.text then table.insert(ret.listeners, ret.text) end
    -- sysfs power_supply
    ret.timer = uzful.util.listen.sysfs({ subsystem = "power_supply", timer = ret.timer },
                                         function (device, props)
        if props.action == "change" and props.power_supply_name == args.ac then
            if props.power_supply_online == "0" then
                power_supply_online = false
                vicious.force(ret.listeners)
            else
                ret.widget.progress:set_background_color(args.charge)
                power_supply_online = true
            end
        elseif props.power_supply_name == args.bat then
            if props.action == "remove" then
                battery_online = false
                ret.widget.progress:set_background_color(args.hidden)
                ret.widget.progress:set_value(nil)
                ret.widget:set_image(args.theme.nobattery)
            elseif props.action == "add" then
                battery_online = true
                ret.widget:set_image(dock_online and args.theme.dock or args.theme.battery)
                vicious.force(ret.listeners)
                if power_supply_online then
                    ret.widget.progress:set_background_color(args.charge)
                end
            end
        end
    end).timer
    -- sysfs dock
    ret.timer = uzful.util.listen.sysfs({ subsystem = "platform", timer = ret.timer },
                                         function (device, props, attrs)
        if props.action == "change" and
        props.modalias == "platform:dock" and
        attrs.type == "dock_station"
        then
            if props.event == "undock" then
                dock_online = false
            elseif props.event == "dock" then
                dock_online = true
            end
            if battery_online then
                ret.widget:set_image(dock_online and args.theme.dock or args.theme.battery)
            end
        end
    end).timer

    return ret
end


function battery.mt:__call(...)
    return new(...)
end

return setmetatable(battery, battery.mt)
