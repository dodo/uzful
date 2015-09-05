
local kdeconnect = {property = {}}

local _, luadbus = pcall(require, "lua-dbus")


-- constants
kdeconnect.BUS = 'session'
kdeconnect.PATH = '/modules/kdeconnect'
kdeconnect.DESTINATION = 'org.kde.kdeconnect'
kdeconnect.INTERFACE = {
    device = 'org.kde.kdeconnect.device',
    battery = 'org.kde.kdeconnect.device.battery',
}

function kdeconnect.on(name, event, callback, path)
    return luadbus.on(event, callback, {
        interface = kdeconnect.INTERFACE[name],
        bus = kdeconnect.BUS,
        path = path,
    })
end

function kdeconnect.call(name, method, callback, path)
    return luadbus.call(method, callback, {
        destination = kdeconnect.DESTINATION,
        interface = kdeconnect.INTERFACE[name],
        path = path or kdeconnect.PATH,
        bus = kdeconnect.BUS,
    })
end


function kdeconnect.property.get(name, key, callback, path)
    return luadbus.property.get(key, callback, {
        destination = kdeconnect.DESTINATION,
        interface = kdeconnect.INTERFACE[name],
        path = path or kdeconnect.PATH,
        bus = kdeconnect.BUS,
    })
end


function kdeconnect.device(id)
    local device = {id = id}
    if id then device.path = kdeconnect.PATH .. '/devices/' .. id end
    device.on = function (name, event, callback)
        return kdeconnect.on(name, event, callback, device.path)
    end
    device.call = function (name, method, callback)
        return kdeconnect.call(name, method, callback, device.path)
    end
    return device
end


return kdeconnect
