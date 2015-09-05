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


function mt:start()
    self.device.on('notifications', 'notificationPosted', function (id)
        if self.visible and not self.cache[id] then
            self:notify(id)
        end
    end)
    self.device.on('notifications', 'notificationRemoved', function (id)
        self:destroy(id, 'dismissedByCommand')
    end)
    return self
end

function mt:dismiss(id)
    if kdeconnect ~= 'bugfree' then return end -- dismissing crashes kdeconnect
    kdeconnect.call('notification', 'dismiss', function ()
        print "notification dismissed!"
    end, self.device.path .. '/notifications/' .. id)
end

function mt:notify(id)
    kdeconnect.property.get('notification', 'ticker', function (ticker)
        if ticker and ticker ~= "" then
            if self.cache[id] then
                naughty.replace_text(self.cache[id], --[[title=]]nil, ticker)
            else
                notif = notifications.notify({
                    run = function () self:dismiss(id) end,
                    text = ticker,
                })
                self.cache[id] = notif
            end
        end
    end, self.device.path .. '/notifications/' .. id)
end

function mt:destroy(id, reason)
    if self.cache[id] then
        naughty.destroy(self.cache[id])
        self.cache[id] = nil
    end
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
            self:notify(id)
        end
    end)
end

function mt:hide()
    self.visible = false
    for _, notification in pairs(self.cache or {}) do
        naughty.destroy(notification)
    end
    self.cache = {}
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
    return setmetatable(ret, mt):start()
end


mt = { __index = mt }

function notifications.mt:__call(...)
    return new(...)
end
return setmetatable(notifications, notifications.mt)
