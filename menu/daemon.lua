
local tags = require("awful.tag")
local util = require("awful.util")
local menu = require("awful.menu")
local capi = {
    client = client }

local daemon = {}

local table_merge = function (t, set)
    for _, v in ipairs(set) do
        table.insert(t, v)
    end
end

function new(args) -- FIXME crude api
    local cls = capi.client.get()
    local cls_t = {}
    for k, c in pairs(cls) do
        local submenu = {
            { "show",
                function ()
                    if #c:tags() == 0 then
                        c:tags(tags.selectedlist())
                    end
                    if not c:isvisible() then
                        tags.viewmore(c:tags(), c.screen)
                    end
                    capi.client.focus = c
                    c:raise()
                end,
            },
        }
        if #c:tags() > 0 then
            table.insert(submenu, { "daemon", function () c:tags({}) end })
        end
        table.insert(cls_t, { util.escape(c.name) or "", submenu, c.icon })
    end
    args = args or {}
    args.items = args.items or {}
    table_merge(args.items, cls_t)

    local m = menu.new(args)
    m:show(args)
    return m
end


setmetatable(daemon, { __call = function (_, ...) return new(...) end })
return daemon