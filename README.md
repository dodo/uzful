# uzful

little library for awesome with the attempt to be useful

## Features

graphs for cpu and network usage for wibox with detailed info boxes.

`uzful.widget.cpugraphs` returns a layout for an infobox to show detailed information about cpu usage.

`uzful.widget.netgraphs` returns a layout for an infobox to show detailed information about network usage (all interfaces).

## Motivation

cleaner awesome/rc.lua

## Dependencies

* [awesome](http://awesome.naquadah.org/)
* [vicious](http://git.sysphere.org/vicious/)

## Usage

    require('uzful')
    uzful.widget.init(vicious)
    uzful.menu.init(beautiful, vicious)
    uzful.util.patch.vicious(vicious)

use netgraphs for instance:

    mynetgraphs = uzful.widget.netgraphs({ label_height = 13,
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

as infobox you can use somthing like this:

    myinfobox.net[s] = uzful.widget.wibox({ screen = s, type = "notification",
            widget = mynetgraphs.big.layout,
            y = theme.menu_height,
            height = mynetgraphs.big.height,
            width = mynetgraphs.big.width,
            x = screen[s].geometry.width - mynetgraphs.big.width,
            ontop = true, visible = false })

## Install

    cd $XDG_CONFIG_HOME/awesome/
    git clone git://github.com/dodo/uzful.git

## Documentation

    luadoc -d doc/ *.lua

## TODO

if you have some nice feature in rc or in mind, let me know about it.
