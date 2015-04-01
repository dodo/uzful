--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2015 https://github.com/dodo
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

local util = { }

local awful = require("awful")
local naughty = require("naughty")
local uzful = { util = require("uzful.util") }


function util.debug()
    -- {{{ Error handling
    -- Check if awesome encountered an error during startup and fell back to
    -- another config (This code will only ever execute for the fallback config)
    if awesome.startup_errors then
        naughty.notify({ preset = naughty.config.presets.critical,
                        title = "Oops, there were errors during startup!",
                        text = awesome.startup_errors })
    end

    -- Handle runtime errors after startup
    do
        local in_error = false
        awesome.connect_signal("debug::error", function (err)
            -- Make sure we don't go into an endless error loop
            if in_error then return end
            in_error = true

            naughty.notify({ preset = naughty.config.presets.critical,
                            title = "Oops, an error happened!",
                            text = err })
            in_error = false
        end)
    end
    -- }}}
end

function util.critical(args)
    args = args or {}
    args.empty = args.empty or 0.1
    args.normal = args.normal or "#000000"
    args.critical = args.critical or "#8C0000"
    if not args.widget then error("widget is missing!") end
    local notification, old_val = nil, args.value or 0
    return uzful.util.threshold(args.threshold or 0.2,
        function (val)
            old_val = val
            local oncolor = args.on and args.on() or args.normal
            args.widget:set_background_color(oncolor)
            if notification then naughty.destroy(notification) end
        end,
        function (val)
            local offcolor = args.off and args.off(val)
            if offcolor then
                if offcolor == true then offcolor = args.critical end
                args.widget:set_background_color(offcolor)
                if notification then naughty.destroy(notification) end
                return
            end
            args.widget:set_background_color(args.critical)
            if val < args.empty and val <= old_val then
                if notification then naughty.destroy(notification) end
                if args.silent then return end
                notification = naughty.notify({
                    preset = naughty.config.presets.critical,
                    title = args.title or "Critical Battery Charge",
                    text = string.format(args.text or "only %d%% remaining.",
                                         val*100)})
            end
            old_val = val
        end)
end

return util
