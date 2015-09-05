--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
--------------------------------------------------------------------------------

local notifications = { mt = {} }
local mt = {}

local naughty = require('naughty')
local util = require('uzful.util')
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
        self:destroy(id)
    end, self.device.path .. '/notifications/' .. id)
end

function mt:notify(id)
    if not id then return end
    kdeconnect.property.get('notification', 'ticker', function (ticker)
        if self.cache['no'] then self:destroy('no') end
        if ticker and ticker ~= "" then
            self.visible = true
            if self.cache[id] then
                naughty.replace_text(self.cache[id], --[[title=]]nil, ticker)
            else
                local notif = notifications.notify({
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
        if id ~= 'no' and util.table.empty(self.cache) then
            self:show_empty()
        end
    end
    if util.table.empty(self.cache) then self.visible = false end
end

function mt:show_empty()
    if not self.cache['no'] then
        self.visible = true
        self.cache['no'] = notifications.notify({
            run = function () self:destroy('no') end,
            text = "no notifications",
        })
    end
end

function mt:show()
    local device = kdeconnect.device(self.id)
    self.device.call('notifications', 'activeNotifications', function (ids)
        if type(ids) ~= 'table' or #ids == 0 then
            return self:show_empty()
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
