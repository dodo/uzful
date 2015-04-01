# uzful

little library for awesome with the attempt to be useful

## Features

graphs for cpu and network usage for wibox with detailed info boxes.

`uzful.widget.cpugraphs` returns a layout for an infobox to show detailed information about cpu usage.

`uzful.widget.netgraphs` returns a layout for an infobox to show detailed information about network usage (all interfaces).

Collection of other useful widgets, extensions and functions.

## Motivation

cleaner awesome/rc.lua

## Dependencies

* [awesome](http://awesome.naquadah.org/) >=3.5
* [vicious](http://git.sysphere.org/vicious/)
* [obvious](http://git.mercenariesguild.net/?p=obvious.git) (optional) needed for uzful.util.volume
* [lua-dbus](https://github.com/dodo/lua-dbus) (optional) needed for uzful.widget.wicd or uzful.widget.battery.phone

## Usage

After `require("beautiful")` and `require("vicious")`:

```lua
require('uzful')
uzful.util.patch.vicious() -- enable auto caching
```

use netgraphs for instance:

```lua
mynetgraphs = uzful.widget.netgraphs({
    label_height = 13, default = "wlan0",
    up_fgcolor = "#D00003", up_bgcolor = "#200000",
    down_fgcolor = "#95D043", down_bgcolor = "#002000",
    highlight = ' <span size="x-small"><b>$1</b></span>',
    normal    = ' <span color="#666666" size="x-small">$1</span>',
    big = { width = 161, height = 42 },
    small = { width = 23, height = theme.menu_height } })
mynetgraphs.small.layout:connect_signal("button::release", mynetgraphs.switch)
for _, widget in ipairs(mynetgraphs.big.widgets) do
    table.insert(detailed_graphs.widgets, widgets)
end
```

as infobox you can use somthing like this:

```lua
myinfobox.net[s] = uzful.widget.wibox({ screen = s, type = "notification",
        widget = mynetgraphs.big.layout,
        y = theme.menu_height,
        height = mynetgraphs.big.height,
        width = mynetgraphs.big.width,
        x = screen[s].geometry.width - mynetgraphs.big.width,
        ontop = true, visible = false })
```

or maybe a battery progressbar in an image:

```lua
mybat = uzful.widget.progressimage(
    { x = 3, y = 4, width = 3, height = 7, image = theme.battery })
uzful.widget.set_properties(mybat.progress, {
    ticks = true, ticks_gap = 1,  ticks_size = 1,
    vertical = true, background_color = theme.bg_normal,
    border_color = nil, color = "#FFFFFF" })
vicious.register(mybat.progress, vicious.widgets.bat, "$2", 45, "BAT0")
-- notifications
mycritbat = uzful.util.threshold(0.2,
    function ()
        mybat.progress:set_background_color(theme.bg_normal)
    end,
    function ()
        mybat.progress:set_background_color("#8C0000")
        naughty.notify({
            preset = naughty.config.presets.critical,
            title = "Critical Battery Charge",
            text = "only " .. (val*100) .. "% remaining." })
    end)
vicious.register(mycritbat, vicious.widgets.bat, "$2", 60, "BAT0")
```

for more examples look at my [awesomerc](https://github.com/dodo/awesomerc).

## Install

```bash
cd $XDG_CONFIG_HOME/awesome/
git clone git://github.com/dodo/uzful.git
```

## Documentation

```bash
luadoc -d doc/ *.lua
```

for more detailed infos look into the [uzful wiki](https://github.com/dodo/uzful/wiki).

## TODO

if you have some nice feature in rc or in mind, let me know about it.
