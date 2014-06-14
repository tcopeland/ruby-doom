#!/usr/local/bin/ruby

require "doom.rb"

if __FILE__ == $0
  if ARGV.include?("-bitmap")
    puts "Creating a map from a bitmap"
    b = BMPMap.new("../bitmaps/wiggly.bmp")
    b.scale_factor = 2
    b.thinning_factor = 10
    b.set_player Point.new(400, 400)
    b.create_wad("new.wad")
  elsif ARGV.include?("-path")
    puts "Creating a simple map using an encoded path"
    m = SimpleLineMap.new(Path.new(0, 1000, "e300/n200/e300/s200/e800/s500/w800/s200/w300/n200/w300/n400"))
    m.set_player Point.new(50,600)
    m.add_shotgun Point.new(150, 600)
    m.add_sergeant Point.new(250, 750)
    m.add_commando Point.new(250, 850)
    m.add_imp Point.new(250, 650)
    400.step(900, 40) {|x| m.add_barrel Point.new(500, x) }
    m.create_wad("new.wad")
    if ARGV.include?("-nethack")
      puts m.nethack
      puts "Map generated from " + m.path.to_s
    end
  elsif ARGV.include?("-repeatingpath")
    puts "Creating a map using a repeated path"
    p = Path.new(0, 1000)
    p.add("e200/n200/e200/s200/e200/",6)
    p.add("s400/")
    p.add("w200/s200/w200/n200/w200/",6)
    p.add("n400/")
    m = SimpleLineMap.new p
    m.set_player Point.new(50,900)
    m.create_wad("new.wad")
    if ARGV.include?("-nethack")
      puts p.nethack(40)
      puts "Map generated from " + p.to_s
    end
  elsif ARGV.include?("-turn")
    puts "Manipulating a current map - changing the player's facing direction"
    w = Wad.new
    w.read ARGV.include?("-f") ? ARGV[ARGV.index("-f") + 1] : "../test_wads/simple.wad"
    w.player.facing_angle = 90
    w.write "new.wad"
  elsif ARGV.include?("-explicit")
    puts "Creating a simple rectangle using clockwise linedefs"
    w = Wad.new(true)
    w.lumps << UndecodedLump.new("MAP01")
    t = Things.new
    t.add_player Point.new(100,400)
    w.lumps << t
    v = Vertexes.new
    v1 = v.add Vertex.new(Point.new(60, 500))
    v2 = v.add Vertex.new(Point.new(600, 500))
    v3 = v.add Vertex.new(Point.new(600, 200))
    v4 = v.add Vertex.new(Point.new(60, 200))
    w.lumps << v
    sectors = Sectors.new
    s1 = sectors.add Sector.new
    w.lumps << sectors
    sidedefs = Sidedefs.new
    sd1 = sidedefs.add Sidedef.new
    sd1.sector_id = s1.id
    sd2 = sidedefs.add Sidedef.new
    sd2.sector_id = s1.id
    sd3 = sidedefs.add Sidedef.new
    sd3.sector_id = s1.id
    sd4 = sidedefs.add Sidedef.new
    sd4.sector_id = s1.id
    w.lumps << sidedefs
    linedefs = Linedefs.new
    linedefs.add Linedef.new(v1,v2,sd1)
    linedefs.add Linedef.new(v2,v3,sd2)
    linedefs.add Linedef.new(v3,v4,sd3)
    linedefs.add Linedef.new(v4,v1,sd4)
    w.lumps << linedefs
  
    w.write("new.wad"  )
  end
end
