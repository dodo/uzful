
local daemons = { mt = {} }

local tags = require("awful.tag")
local util = require("awful.util")
local menu = require("awful.menu")
local capi = {
    client = client }

local table_merge = function (t, set)
    for _, v in ipairs(set) do
        table.insert(t, v)
    end
end

function daemons.new(args) -- FIXME crude api
    local cls = capi.client.get()
    local cls_t = {}
    for k, c in pairs(cls) do
        if #c:tags() > 0 then
            table.insert(cls_t, { util.escape(c.name) or "", function ()
                c:tags({})
            end, c.icon })
        end
    end
    args = args or {}
    args.items = args.items or {}
    table_merge(args.items, cls_t)

    local m = menu.new(args)
    m:show(args)
    return m
end

function daemons.clients(args) -- FIXME crude api
    local cls = capi.client.get()
    local cls_t = {}
    for k, c in pairs(cls) do
        table.insert(cls_t, { util.escape(c.name) or "", function ()
            if #c:tags() == 0 then
                c:tags(tags.selectedlist())
            end
            if not c:isvisible() then
                tags.viewmore(c:tags(), c.screen)
            end
            capi.client.focus = c
            c:raise()
        end, c.icon })
    end
    args = args or {}
    args.items = args.items or {}
    table_merge(args.items, cls_t)

    local m = menu.new(args)
    m:show(args)
    return m
end

function daemons.mt:__call(_, ...)
    return daemons.new(...)
end

return setmetatable(daemons, daemons.mt)
