

local Wibox = require("wibox")

module("uzful.util")

function wibox(args)
    local w = Wibox(args)
    w.screen = args.screen or 1
    w.visible = args.visible or false
    return w
end
