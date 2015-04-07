--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local naughty = require("naughty")

local switch = {}

local capi = {
    screen = screen,
}


function switch.toggle(opts)
    if not opts or not opts.toggle then error("opts.toggle is missing!") end
    if not opts.test then error("opts.test is missing!") end
    opts.labels = opts.labels or {}
    local menu_toggle_text = function ()
        return opts.labels[opts.test()]
    end
    return { menu_toggle_text(), function (m)
        opts.toggle()
        m.label:set_text(menu_toggle_text())
        return true -- dont close menu
    end,
        theme = opts.theme,
        menu_text = menu_toggle_text,
    }
end


function switch.filter(opts)
    if not opts or not opts.filter then error("opts.filter is missing!") end
    opts.labels = opts.labels or {}
    local menu_filter_text = function ()
        return opts.labels[opts.filter.current()]
            or ("filter option " .. tostring(opts.filter.current()))
    end
    return { menu_filter_text(), function (m)
        opts.filter.next()
        m.label:set_text(menu_filter_text())
        -- update menu filters
        for s = 1, capi.screen.count() do
            tags[s][1].name = tags[s][1].name
        end
        return true -- dont close menu
    end,
        theme = opts.theme,
        menu_text = menu_filter_text,
    }
end


function switch.numbered_tag_names(tags, opts)
    opts = opts or {}
    opts.names = opts.names or {}
    opts.label = opts.label or {}
    opts.label.tags = opts.label.tags or "tags"
    opts.label.named = opts.label.named or "named"
    opts.label.numbered = opts.label.numbered or "number"
    local menu_tags_text = function ()
        return (opts.numbered and opts.label.named or opts.label.numbered)
            .. " " .. opts.label.tags
    end
    if opts.numbered == nil then opts.numbered = #opts.names > 0 end
    if opts.numbered then
        for s = 1, capi.screen.count() do
            for i, t in ipairs(tags[s]) do
                t.name = tostring(i)
            end
        end
    end
    return { menu_tags_text(), function (m) -- this is a menu entry
        opts.numbered = not opts.numbered
        for s = 1, capi.screen.count() do
            for i, t in ipairs(tags[s]) do
                t.name = not opts.numbered and opts.names[i] or tostring(i)
            end
        end
        m.label:set_text(menu_tags_text())
        return true -- dont close menu
    end,
        theme = opts.theme,
        menu_text = menu_tags_text,
    }
end


function switch.naughty(opts)
    opts = opts or {}
    opts.label = opts.label or {}
    opts.label.on  = opts.label.on or "disable"
    opts.label.off = opts.label.off or "enable"
    opts.label.name = opts.label.name or "notifications"
    if naughty.is_suspended then -- if patched with uzful.util.patch.naughty
        if opts.enabled == nil then opts.enabled = naughty.is_suspended() end
    else
        if opts.enabled == nil then opts.enabled = true end
        if opts.enabled then
            naughty.resume()
        else
            naughty.suspend()
        end
    end
    local menu_naughty_text = function ()
        return (opts.enabled and opts.label.on or opts.label.off)
            .. " " .. opts.label.name
    end
    local entry
    entry = { menu_naughty_text(), function (m)
        entry.m = m
        opts.enabled = not opts.enabled
        -- force switch value
        if opts.enabled then
            naughty.resume()
        else
            naughty.suspend()
        end
        m.label:set_text(menu_naughty_text())
        return true -- dont close menu
    end,
        theme = opts.theme,
        menu_text = menu_tags_text,
    }
    if naughty.connect_signal then -- if patched with uzful.util.patch.naughty
        naughty.connect_signal('toggle', function (suspended)
            opts.enabled = not suspended
            entry[1] = menu_naughty_text()
            if entry.m then
                entry.m.label:set_text(menu_naughty_text())
            end
        end)
    end
    return entry
end


return switch

