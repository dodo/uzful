--------------------------------------------------------------------------------
-- @author dodo
-- @copyright 2011 https://github.com/dodo
-- @release v3.4-503-g4972a28
-- original code made by Bzed and published on http://awesome.naquadah.org/wiki/Calendar_widget
--------------------------------------------------------------------------------

local calendar = { mt = {} }

local _, helper = pcall(require, "vicious.helpers")
local wibox = require("wibox")


local center_text = function (text, size, maxs, char)
    if size >= maxs then return text end
    local ret = string.rep(char, math.ceil((maxs - size) / 2))
    return ret .. text .. ret
end


local generate = function (month,year,weekStart, format)
        local t,wkSt=os.time{year=year, month=month+1, day=0},weekStart or 1
        local d=os.date("*t",t)
        local mthDays,stDay=d.day,(d.wday-d.day-wkSt+1)%7

        --print(mthDays .."\n" .. stDay)
        local lines = "    "

        for x=0,6 do
            lines = lines .. helper.format(format.day,
                {os.date("%a ",os.time{year=2006,month=1,day=x+wkSt})})
        end

        lines = lines .. "\n" .. helper.format(format.week,
            {os.date(" %V",os.time{year=year,month=month,day=1})})

        local writeLine = 1
        while writeLine < (stDay + 1) do
            lines = lines .. "    "
            writeLine = writeLine + 1
        end

        for d=1,mthDays do
            local x = d
            local t = os.time{year=year,month=month,day=d}
            if writeLine == 8 then
                writeLine = 1
                lines = lines .. "\n" ..
                    helper.format(format.week, {os.date(" %V",t)})
            end
            x = helper.format(os.date("%Y-%m-%d") == os.date("%Y-%m-%d", t) and
                format.current or format.number, {d})
            if (#(tostring(d)) == 1) then
                x = " " .. x
            end
            lines = lines .. "  " .. x
            writeLine = writeLine + 1
        end
        local header = os.date("%B %Y\n",os.time{year=year,month=month,day=1})
        header = center_text(helper.format(format.head, {header}),#header, 32," ")

        return header .. "\n" .. lines
end

--- Changes calendar month
-- @param cal calendar
-- @param month month diff (-1 or 2 or smth else (number))
function calendar.switch_month(cal, month)
    cal.month = cal.month + month
    cal:update()
end

--- Changes calendar year
-- @param cal calendar
-- @param year year diff (-1 or 2 or smth else (number))
function calendar.switch_year(cal, year)
    cal.year = cal.year + year
    cal:update()
end

--- Sets calendar to current date
-- @param cal calendar
function calendar.now(cal)
    cal.month = os.date('%m')
    cal.year = os.date('%Y')
    cal:update()
end

--- Calendar Widget
-- every day calendar
-- @param args <i>(optional) </i> table with all relevant properties
-- @param args.start <i>(default: 2 (monday)) </i> specify the week start day
-- @param args.font <i>/default: 'monospace') </i> text font or text size if number
-- @param args.year <i>(default: os.date('%Y')) </i> year to be displayed
-- @param args.month <i>(default: os.date('%m')) </i> month to be displayed
-- @param args.number <i>/default: '$1') </i> format string for all days
-- @param args.current <i>/default: '$1') </i> format string for current date
-- @param args.day <i>/default: '$1') </i> format string for all week days
-- @param args.week <i>/default: '$1') </i> format string for all week numbers
-- @param args.head <i>/default: '$1') </i> format string for header
-- @param args.all <i>/default: '$1') </i> format string for complete text
local function new(args)
    args = args or {}
    args.font = args.font or "monospace"
    if type(args.font) == "number" then
        args.font = "monospace " .. tostring(args.font)
    end
    local ret = {}
    ret.month = args.month or os.date('%m')
    ret.year = args.year or os.date('%Y')
    ret.start = args.start or 2
    local format = {}
    for _, k in pairs({"day", "week", "current", "head", "number"}) do
        format[k] = args[k] or "$1"
    end
    ret.widget = wibox.widget.textbox()
    ret.update = function ()
        ret.text = generate(ret.month, ret.year, ret.start, format)
        ret.text = helper.format(args.all or "$1", {ret.text})
        ret.widget:set_markup(ret.text)
        ret.widget:set_font(args.font)
        ret.width, ret.height = ret.widget:fit(-1, -1)
    end
    ret:update()
    ret.switch_month = calendar.switch_month
    ret.switch_year = calendar.switch_year
    ret.now = calendar.now
    return ret
end

function calendar.mt:__call(...)
    return new(...)
end

return setmetatable(calendar, calendar.mt)
