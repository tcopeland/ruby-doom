# Description

Ruby-DOOM provides a scripting API to DOOM level maps.

## Overview

You can make a map using a Ruby script and a "path
specification", like this:

    m = SimpleLineMap.new(Path.new(0, 1000, "e300/n200/e300/s200/e800/s500/w800/s200/w300/n200/w300/n400"))
    m.set_player Point.new(50,900)
    m.add_shotgun Point.new(150, 900)
    m.add_sergeant Point.new(400,700)
    m.add_imp Point.new(400,700)
    m.add_commando Point.new(400,700)
    550.step(900, 40) {|x| m.add_barrel Point.new(x,900) }
    m.create_wad("new.wad")

Or, you can convert a bitmap into a map like this:

    b = BMPMap.new("wiggly.bmp")
    b.set_player Point.new(400, 200)
    b.create_wad("new.wad")

Ruby-DOOM can also parse any DOOM II map into an object model.  Run it like this:

    ./doom.rb [-v] -f simple.wad

and it'll produce a list of the lumps (things, vertexes, sectors, etc) contained within the file.

Please see the [www/](https://cdn.rawgit.com/tcopeland/ruby-doom/master/www/) directory for more detailed information, and
the file "examples.rb" for more examples.

## Doing the next release

* Update the version number
* Update CHANGELOG
* Update README to reflect current capabilities
* Make sure the tests run
* Check everything in
* bundle exec gem build ruby-doom.gemspec
