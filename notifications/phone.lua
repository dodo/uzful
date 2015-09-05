--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
--------------------------------------------------------------------------------

local notifications = { mt = {} }
local mt = {}

local naughty = require('naughty')
local kdeconnect = require("uzful.ext.kdeconnect")

notifications.preset = {
    bg = "#C4C3AE",
    fg = "#000000",
    timeout = 0,
}

function notifications.notify(args)
    args.preset = args.preset or notifications.preset
    return naughty.notify(args)
end


function mt:show()
    self.visible = true
    local device = kdeconnect.device(self.id)
    self.device.call('notifications', 'activeNotifications', function (ids)
        if #ids == 0 then
            naughty.notify({text = "no notifications"})
            self.visible = false
            return
        end
        for _, id in ipairs(ids) do
            kdeconnect.property.get('notification', 'ticker', function (ticker)
                if ticker and ticker ~= "" then
                    notif = notifications.notify({text = ticker})
                    self.cache[notif.id] = notif
                end
            end, self.device.path .. '/notifications/' .. id)
        end
    end)
end

function mt:hide()
    self.visible = false
    for _, notification in pairs(self.cache or {}) do
        naughty.destroy(notification)
    end
end

function mt:toggle()
    if self.visible then
        self:hide()
    else
        self:show()
    end
end


local function new(id)
    local ret = {cache = {}, visible = false}
    ret.device = kdeconnect.device(id)
    return setmetatable(ret, mt)
end


mt = { __index = mt }

function notifications.mt:__call(...)
    return new(...)
end
return setmetatable(notifications, notifications.mt)
