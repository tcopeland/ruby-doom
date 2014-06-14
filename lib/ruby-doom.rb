#!/usr/local/bin/ruby

class RubyDoom
  VERSION = '0.9.0'
end

class RGBQuad
  def initialize(bytes)
    @r,@g,@b,@res = *bytes
  end
  def to_s
    return @r.to_s + "," + @g.to_s + "," + @b.to_s
  end
end

class Finder
  def initialize(points, max_radius=5, debug=false)
    @debug=debug
    @max_radius = max_radius
    @points = points
  end
  def next(current, sofar)
    1.upto(@max_radius) do |x|
      points_at_radius(current, x).each {|p| return p if good(p, sofar) }
    end
    raise "Couldn't find next point!"
  end
  def points_at_radius(p, r)
    res = []
    puts "checking for points around " + p.to_s + " at radius " + r.to_s unless !@debug
    # move up and then west to the upper left hand corner of the search box
    p = p.translate(-r, r)
    res << p
    # move east
    1.upto(r*2) {
      p = p.translate(1,0)
      res << p
    }
    # move south
    1.upto(r*2) {
      p = p.translate(0,-1)
      res << p
    }
    # move west
    1.upto(r*2) {
      p = p.translate(-1,0)
      res << p
    }
    # move north
    1.upto((r*2)-1) {
      p = p.translate(0,1)
      res << p
    }
    puts "points array = " + res.to_s unless !@debug
    res
  end
  def good(candidate, sofar)  
    puts "Testing " + candidate.to_s unless !@debug
    @points.include?(candidate) && !sofar.include?(candidate)
  end
end

class PointThinner
  def initialize(p, factor)
    @points = p
    @factor = factor
  end
  def thin
    newline = [@points[0]]
    1.upto(@points.size-1) {|x| newline << @points[x] if x % @factor == 0 }
    newline  
  end
end

class PointsToLine
  def initialize(points, debug=false)
    @points = points
    @debug = debug
  end
  def lower_left
    @points.min {|a,b| a.distance_to(Point.new(0,0)) <=> b.distance_to(Point.new(0,0)) }
  end
  def line
    @f = Finder.new(@points, 5, @debug)
    found_so_far = [lower_left]
    current = @f.next(found_so_far[0], found_so_far)
    while found_so_far.size != @points.size - 1 
      found_so_far << current
      puts "Current = " + current.to_s + "; points so far: " + found_so_far.size.to_s unless !@debug
      begin
        current = @f.next(current, found_so_far)
      rescue
        puts "Couldn't find next point, so skipping back to the origin" unless !@debug
        break
      end
    end
    found_so_far << current
  end
end

class ArrayToPoints
  def initialize(width, height, raw_data)
    @width = width
    @height = height
    @raw_data = raw_data
  end
  def points
    pts = []
    # for each byte in the image
    idx = 0
    @raw_data.each do |byte|
      # for each bit in the image
      0.upto(7) do |bit|
        if (byte &  128 >> bit) == 0
          tmp_pt = convert(idx, @width)
          pts << Point.new(tmp_pt.x, @height-1-tmp_pt.y)
        end
        idx += 1
      end
    end
    return pts
  end
  # converts an index into an array of width blah to a point on an x/y coordinate plane
  # with 0,0 in the upper left hand corner
  # so in an array that's 8 units wide, unit 12 converts to a point 4 across, 1 down
  def convert(idx, width)
    Point.new(idx % width, idx/width)
  end
end

class BMPDecoder
  attr_reader :type, :size, :offset_to_image_data, :info_header_size, :width, :height, :bit_planes, :bits_per_pixel, :compression, :size_of_image, :xpixels_per_meter, :ypixels_per_meter, :colors_used, :colors_important
  attr_accessor :scale_factor, :thinning_factor
  def initialize(filename, debug=false)
    @debug = debug
    @filename = filename
    @scale_factor = 1
    @thinning_factor = 5
  end
  def decode
    # hm, wouldn't File.read(filename, "rb") do this?
    bytes = []
    File.open(@filename, "r").each_byte {|x| bytes << x }
    
    # decode BITMAPFILEHEADER 
    @type = decode_word(bytes.slice(0,2))
    raise "Can only decode bitmaps" unless @type == 19778

    @size = decode_dword(bytes.slice(2,4))
    res1 = decode_word(bytes.slice(6,2))
    res1 = decode_word(bytes.slice(8,2))
    @offset_to_image_data = decode_dword(bytes.slice(10,4))
    
    # decode BITMAPINFOHEADER
    @info_header_size = decode_dword(bytes.slice(14,4))
    @width = decode_dword(bytes.slice(18,4)) # specified as a LONG... but DWORD works... (?)
    @height = decode_dword(bytes.slice(22,4)) #  specified as a LONG... but DWORD works... (?)
    @bit_planes = decode_word(bytes.slice(26,2))
    @bits_per_pixel = decode_word(bytes.slice(28,2))
    raise "Can't process bitmaps with more than one bit per pixel.  Save it as a monochrome bitmap to fix this." unless @bits_per_pixel == 1

    @compression = decode_dword(bytes.slice(30,4))
    raise "Can't process compressed bitmaps" unless @compression == 0

    @size_of_image = decode_dword(bytes.slice(34,4))
    @xpixels_per_meter = decode_dword(bytes.slice(38,4)) # specified as a LONG... but DWORD works... (?)
    @ypixels_per_meter = decode_dword(bytes.slice(42,4)) # specified as a LONG... but DWORD works... (?)
    @colors_used = decode_dword(bytes.slice(46,4))
    @colors_important = decode_dword(bytes.slice(50,4))
    
    # color table - assume monochrome bitmap for now
    rgb1 = RGBQuad.new(bytes.slice(54,4))
    rgb2 = RGBQuad.new(bytes.slice(58,4))
  
    @raw_image = bytes.slice(62, bytes.size-62)
    self
  end
  def raw_points
    decode if @raw_image.nil?
    ArrayToPoints.new(@width, @height, @raw_image).points
  end
  def line
    PointsToLine.new(raw_points, @debug).line
  end
  def thin
    pts = PointThinner.new(line, @thinning_factor).thin
    pts.collect {|p| p.scale(@scale_factor) }  
  end
  def decode_word(bytes)
    bytes.pack("C2").unpack("S")[0] 
  end
  def decode_dword(bytes)
    bytes.pack("C4").unpack("L")[0] 
  end
end

class Codec
  # Accepts a format string like "sl48" and a byte array
  # s - short
  # l - long
  # 4 - 4 byte string
  # 8 - 8 bytes string
  def Codec.decode(format, bytes)
    res = []
    ptr = 0
    format.split(//).each {|x|
      if x == "s"
        res << bytes.slice(ptr,2).pack("c2").unpack("s")[0]
        ptr += 2
      elsif x == "l"  
        res << bytes.slice(ptr,4).pack("C4").unpack("V")[0]
        ptr += 4
      elsif x == "4"
        res << Codec.unmarshal_string(bytes.slice(ptr,4))
        ptr += 4
      elsif x == "8"
        res << Codec.unmarshal_string(bytes.slice(ptr,8))
        ptr += 8
      else
        raise "Unknown character in decode format string " + format
      end
    }
    return res
  end
  # Accepts a format string like "sl48" and an array of values 
  def Codec.encode(format, values)
    bytes = []  
    ptr = 0
    format.split(//).each {|x|
      if x == "s"
        bytes += [values[ptr]].pack("S").unpack("C2")
      elsif x == "l"  
        bytes += [values[ptr]].pack("N").unpack("C4").reverse
      elsif x == "4"
        bytes += Codec.marshal_string(values[ptr],4)
      elsif x == "8"
        bytes += Codec.marshal_string(values[ptr],8)
      else
        raise "Unknown character in decode format string " + format
      end
      ptr += 1
    }
    return bytes
  end
  def Codec.unmarshal_string(a)
    a.pack("C*").strip
  end
  def Codec.marshal_string(n,len)
    arr = n.unpack("C#{len}").compact
    if arr.size < len
      arr += Array.new(len-arr.size, 0)
    end
    arr
  end
end

class ThingInfo
  attr_reader :id, :name, :symbol
  def initialize(id,name,symbol)
    @id, @name, @symbol = id,name,symbol
  end
end

class Dictionary
  def Dictionary.get
    if @self.nil?
      @self = Dictionary.new
    end
    return @self
  end
  def initialize
    @things = []
    @things << ThingInfo.new(1, "Player 1", "@")
    @things << ThingInfo.new(9, "Sergeant", "s")
    @things << ThingInfo.new(65, "Commando", "c")
    @things << ThingInfo.new(2001, "Shotgun", "g")
    @things << ThingInfo.new(3001, "Imp", "i")
    @things << ThingInfo.new(2035, "Barrel", "b")
  end
  def thing_for_type_id(id) 
    t = @things.find {|x| x.id == id}
    return ThingInfo.new(-999, "Unknown thing", "?") if t.nil?
    t
  end
  def thing_for_name(name) 
    @things.find {|x| x.name == name}
  end
  def direction_for_angle(angle)
    case angle
    when (0..45 or 316..360) then return "east"
    when 46..135 then return "north"
    when 136..225 then return "west"
    when 225..315 then return "south"
    end
    raise "Angle must be between 0 and 360"
  end
end

class Point
  attr_accessor :x, :y
  def initialize(x,y)
    @x=x
    @y=y
  end
  def scale(factor)
    Point.new(x * factor, y * factor)
  end
  def ==(other)
    return other.x == @x && other.y == @y
  end
  def slope_to(p1)
    if (p1.x - @x) == 0
      return nil
    end
    (p1.y - @y) / (p1.x - @x)
  end
  def distance_to(p1)
    Math.sqrt(((p1.x - @x) ** 2) + ((p1.y - @y) ** 2))
  end
  def lineto(p1)
    res = []
    current_x = @x
    current_y = @y  
    slope = slope_to(p1)
    res << Point.new(current_x, current_y)
    distance_to(p1).to_i.times {|s|
      if slope == 0
        current_x += (p1.x < @x ? -1 : 1)
        res << Point.new(current_x, current_y)
        next  
      end
  
      if slope == nil
        current_y += (p1.y < @y ? -1 : 1)
        res << Point.new(current_x, current_y)
        next  
      end

      current_x += slope
      cur += (1-slope)
      res << Point.new(current_x, current_y)
    }
    res << p1
    return res
  end
  def translate(x,y)
    Point.new(@x + x, @y + y)
  end
  def to_s
    "(" + @x.to_s + "," + @y.to_s + ")"
  end
end

class Lump
  attr_reader :name
  def initialize(name)
    @name = name
  end
end

class DecodedLump < Lump
  attr_reader :items
  def initialize(name)
    super(name)
    @items = []
    @index = 0
  end
  def add(i)
    i.id = @index
    @index += 1
    @items << i
    return i
  end
  def write
    out = []
    @items.each {|i| out += i.write }
    out
  end
end

class UndecodedLump < Lump
  def initialize(name)
    super(name)
    @bytes = []
  end
  def read(bytes)
    @bytes = bytes
  end
  def write
    @bytes
  end
  def size
    @bytes.size
  end
  def items
    []
  end
end

class Sectors < DecodedLump
  BYTES_EACH=26
  NAME="SECTORS"
  def initialize
    super(NAME)
  end
  def read(bytes)
    (bytes.size / BYTES_EACH).times {|index|
      s = Sector.new
      s.read(bytes.slice(index*BYTES_EACH, BYTES_EACH))
      @items << s
    }
  end
  def size
    @items.size * BYTES_EACH
  end
end

class Sector
  FORMAT="ss88sss"
  attr_accessor :floor_height, :ceiling_height, :floor_texture, :ceiling_texture, :light_level, :special, :tag, :id
  def initialize
    @floor_height, @ceiling_height, @floor_texture, @ceiling_texture, @light_level, @special, @tag = 0, 128, "FLAT14", "FLAT14", 160, 0, 0
  end
  def read(bytes)
    @floor_height, @ceiling_height, @floor_texture, @ceiling_texture, @light_level, @special, @tag = Codec.decode(FORMAT, bytes)
  end
  def write
    Codec.encode(FORMAT, [@floor_height, @ceiling_height, @floor_texture, @ceiling_texture, @light_level, @special, @tag])
  end
  def to_s
    " Sector floor/ceiling heights " + @floor_height.to_s + "/" + @ceiling_height.to_s + "; floor/ceiling textures " + @floor_texture.to_s + "/" + @ceiling_texture.to_s + "; light = " + @light_level.to_s + "; special = " + @special.to_s + "; tag = " + @tag.to_s
  end
end

class Vertexes < DecodedLump
  BYTES_EACH=4
  NAME="VERTEXES"
  def initialize
    super(NAME)
  end
  def read(bytes)
    (bytes.size / BYTES_EACH).times {|index|
      v = Vertex.new
      v.read(bytes.slice(index*BYTES_EACH, BYTES_EACH))
      @items << v
    }
  end
  def size
    @items.size * BYTES_EACH
  end
end

class Vertex
  FORMAT="ss"
  attr_reader :location 
  attr_accessor :id
  def initialize(location=nil)
    @location = location
  end  
  def read(bytes)
    @location = Point.new(*Codec.decode(FORMAT, bytes))
  end
  def write
    Codec.encode(FORMAT, [@location.x, @location.y])
  end
  def to_s
    " Vertex at " + @location.to_s
  end
end

class Sidedefs < DecodedLump
  BYTES_EACH=30
  NAME="SIDEDEFS"
  def initialize
    super(NAME)
  end
  def read(bytes)
    (bytes.size / BYTES_EACH).times {|index|
      s = Sidedef.new
      s.read(bytes.slice(index*BYTES_EACH, BYTES_EACH))
      @items << s
    }
  end
  def size
    @items.size * BYTES_EACH
  end
end

class Sidedef
  FORMAT="ss888s"
  attr_accessor :x_offset, :y_offset, :upper_texture, :lower_texture, :middle_texture, :sector_id, :id
  def initialize()
    @x_offset=0
    @y_offset=0
    @upper_texture="-"
    @lower_texture="-"
    @middle_texture="BROWN96"
    @sector_id=0
  end
  def read(bytes)
    @x_offset, @y_offset, @upper_texture, @lower_texture, @middle_texture, @sector_id = Codec.decode(FORMAT, bytes)
  end
  def write
    Codec.encode(FORMAT, [@x_offset, @y_offset, @upper_texture, @lower_texture, @middle_texture, @sector_id])
  end
  def to_s
    " Sidedef for sector " + @sector_id.to_s + "; upper/lower/middle textures are " + @upper_texture + "/" + @lower_texture + "/" + @middle_texture + " with offsets of " + @x_offset.to_s + "/" + @y_offset.to_s
  end
end

class Things < DecodedLump
  BYTES_EACH=10
  NAME="THINGS"
  def initialize
    super(NAME)
  end
  def read(bytes)
    (bytes.size / BYTES_EACH).times {|index|
      thing = Thing.new
      thing.read(bytes.slice(index*BYTES_EACH, BYTES_EACH))
      @items << thing
    }
  end
  def size
    @items.size * BYTES_EACH
  end
  def add_sergeant(p)
    items << Thing.new(p, Dictionary.get.thing_for_name("Sergeant").id)
  end
  def add_commando(p)
    items << Thing.new(p, Dictionary.get.thing_for_name("Commando").id)
  end
  def add_barrel(p)
    items << Thing.new(p, Dictionary.get.thing_for_name("Barrel").id)
  end
  def add_shotgun(p)
    items << Thing.new(p, Dictionary.get.thing_for_name("Shotgun").id)
  end
  def add_imp(p)
    items << Thing.new(p, Dictionary.get.thing_for_name("Imp").id)
  end
  def add_player(p)  
    items << Thing.new(p, Dictionary.get.thing_for_name("Player 1").id)
  end
  def player
    @items.find {|t| t.type_id == Dictionary.get.thing_for_name("Player 1").id} 
  end
end

class Thing
  attr_reader :type_id, :location
  attr_accessor :facing_angle, :id
  def initialize(p=nil,type_id=0)
    @location = p
    @facing_angle = 0
    @type_id = type_id
    @flags = 7
  end
  def read(bytes)
    x, y, @facing_angle, @type_id, @flags = Codec.decode("sssss", bytes)
    @location = Point.new(x,y)
  end
  def write
    Codec.encode("sssss", [@location.x, @location.y, @facing_angle, @type_id, @flags])
  end
  def to_s
    Dictionary.get.thing_for_type_id(@type_id).name  + " at " + @location.to_s + " facing " + Dictionary.get.direction_for_angle(@facing_angle) + "; flags = " + @flags.to_s
  end
end

class Linedefs < DecodedLump
  BYTES_EACH=14
  NAME="LINEDEFS"
  def initialize
    super(NAME)
  end
  def read(bytes)
    (bytes.size / BYTES_EACH).times {|index|
      linedef = Linedef.new
      linedef.read(bytes.slice(index*BYTES_EACH, BYTES_EACH))
      @items << linedef
    }
  end
  def size
    @items.size * BYTES_EACH
  end
end

class Linedef
  FORMAT="sssssss"
  attr_accessor :start_vertex, :end_vertex, :attributes, :special_effects_type, :right_sidedef, :left_sidedef, :id
  def initialize(v1=0,v2=0,s=0)
    @start_vertex=v1
    @end_vertex=v2
    @attributes=1
    @special_effects_type=0
    @right_sidedef=s
    @left_sidedef=-1
  end
  def read(bytes)
    @start_vertex, @end_vertex, @attributes, @special_effects_type, @tag, @right_sidedef, @left_sidedef = Codec.decode(FORMAT, bytes)
  end
  def write
    Codec.encode(FORMAT, [@start_vertex.id, @end_vertex.id, @attributes, @special_effects_type, @tag, @right_sidedef.id, -1])
  end
  def to_s
    "Linedef from " + @start_vertex.to_s + " to " + @end_vertex.to_s + "; attribute flag is " + @attributes.to_s + "; special fx is " + @special_effects_type.to_s + "; tag is " + @tag.to_s + "; right sidedef is " + @right_sidedef.to_s + "; left sidedef is " + @left_sidedef.to_s
  end
end

class DirectoryEntry
  BYTES_EACH=16
  attr_accessor :offset, :size, :name
  def initialize(offset=nil,size=nil,name=nil)
    @offset = offset
    @size = size
    @name = name
  end
  def read(array)
      @offset, @size, @name = Codec.decode("ll8", array)
  end
  def write
    Codec.encode("ll8", [@offset, @size, @name])
  end
  def create_lump(bytes)
    lump=nil
    if @name == Things::NAME
      lump=Things.new
    elsif @name == Linedefs::NAME
      lump=Linedefs.new
    elsif @name == Sidedefs::NAME
      lump=Sidedefs.new
    elsif @name == Vertexes::NAME
      lump=Vertexes.new
    elsif @name == Sectors::NAME
      lump=Sectors.new
    else
      lump=UndecodedLump.new(@name)
    end
    lump.read(bytes.slice(@offset, @size))
    return lump
  end
  def to_s
    @offset.to_s + "," + @size.to_s + "," + @name
  end
end

class Header
  BYTES_EACH=12
  attr_reader :type
  attr_accessor :directory_offset, :lump_count
  def initialize(type=nil)  
    @type = type
  end
  def read(array)
    @type, @lump_count, @directory_offset = Codec.decode("4ll", array)
  end
  def write
    Codec.encode("4ll", [@type, @lump_count, @directory_offset])
  end
end

class Wad
  attr_reader :directory_offset, :header, :bytes, :lumps
  def initialize(verbose=false)
    @verbose = verbose
    @bytes = []
    @lumps = []
  end
  def read(filename)
    puts "Reading WAD into memory" unless !@verbose
    File.new(filename).each_byte {|b| 
      @bytes << b 
      puts "Read " + (@bytes.size/1000).to_s + " KB so far " unless (!@verbose or @bytes.size % 500000 != 0)
    }
    puts "Done reading, building the object model" unless !@verbose
    @header = Header.new
    @header.read(@bytes.slice(0,Header::BYTES_EACH))
    @header.lump_count.times {|directory_entry_index|
      de = DirectoryEntry.new
      de.read(@bytes.slice((directory_entry_index*DirectoryEntry::BYTES_EACH)+@header.directory_offset,DirectoryEntry::BYTES_EACH))
      lump = de.create_lump(@bytes)
      puts "Created " + lump.name unless !@verbose
      @lumps << lump
    }
    puts "Object model built" unless !@verbose
    puts "The file " + filename + " is a " + @bytes.size.to_s + " byte " + @header.type unless !@verbose
    puts "It's got " + @lumps.size.to_s + " lumps, the directory started at byte " + @header.directory_offset.to_s unless !@verbose
  end
  def player
    @lumps.find {|x| x.name == "THINGS"}.player
  end
  def write(filename=nil)
    puts "Writing WAD" unless !@verbose
    out = []
    ptr = Header::BYTES_EACH
    entries = []
    @lumps.each {|lump|
      entries << DirectoryEntry.new(ptr, lump.size, lump.name)
      out += lump.write
      ptr += lump.size
    }
    entries.each {|e| out += e.write }
    # now go back and fill in the directory offset in the header
    h = Header.new("PWAD")
    h.directory_offset = ptr
    h.lump_count = @lumps.size
    out = h.write + out
    File.open(filename, "w") {|f| out.each {|b| f.putc(b) } } unless filename == nil
    puts "Done" unless !@verbose
    return out
  end
end

class SimpleLineMap
  attr_reader :path
  def initialize(path)
    @path = path
    @things = Things.new
  end
  def set_player(p)
    @things.add_player p
  end
  def add_barrel(p)
    @things.add_barrel p  
  end  
  def add_sergeant(p)
    @things.add_sergeant p  
  end  
  def add_commando(p)
    @things.add_commando p  
  end  
  def add_imp(p)
    @things.add_imp p  
  end  
  def add_shotgun(p)
    @things.add_shotgun p  
  end  
  def nethack(size=Nethack::DEFAULT_SIZE)
    n = Nethack.new(@path.start, size)
    @path.visit(n)
    @things.items.each {|t| n.thing(t) }
    return n.render
  end
  def create_wad(filename)
    w = Wad.new
    w.lumps << UndecodedLump.new("MAP01")
    w.lumps << @things
    pc = PathCompiler.new(@path)
    w.lumps.concat pc.lumps
    w.write(filename)
  end
end

class BMPMap
  attr_accessor :scale_factor, :thinning_factor
  def initialize(file)
    @things = Things.new
    @scale_factor = 1
    @thinning_factor = 5
    @bitmap_file = file
  end
  def set_player(p)
    @things.add_player p
  end
  def add_sergeant(p)
    @things.add_sergeant p
  end
  def add_commando(p)
    @things.add_commando p  
  end  
  def add_imp(p)
    @things.add_imp p  
  end  
  def add_shotgun(p)
    @things.add_shotgun p
  end
  def create_wad(filename)
    b = BMPDecoder.new(@bitmap_file)
    b.scale_factor = @scale_factor
    b.thinning_factor = @thinning_factor
    w = Wad.new
    w.lumps << UndecodedLump.new("MAP01")
    w.lumps << @things
    pc = PathCompiler.new(PointsPath.new(b.thin))
    w.lumps.concat(pc.lumps)
    w.write(filename)
  end
end

class PathCompiler
  def initialize(path)
    @path = path
    @sectors = Sectors.new
    @sectors.add(Sector.new)
    @vertexes = Vertexes.new
    @vertexes.add(Vertex.new(@path.start))
    @path.visit(self)
    @sidedefs = Sidedefs.new
    @path.segment_count.times do |v|
      s = @sidedefs.add Sidedef.new
      s.sector_id = @sectors.items[0].id  
    end
    @linedefs = Linedefs.new
    last = nil
    @vertexes.items.each do |v|
      if last.nil?
        last = v
        next
      end
      @linedefs.add Linedef.new(last, v, @sidedefs.items[last.id])
      last = v
    end
    @linedefs.add(Linedef.new(@vertexes.items.last, @vertexes.items.first, @sidedefs.items.last))
  end
  def line_to(p)
    @vertexes.add(Vertex.new(p)) if (@vertexes.items.find {|x| x.location == p }).nil?
  end
  def lumps
    [@vertexes, @sectors, @linedefs, @sidedefs]
  end
end

class PointsPath
  def initialize(points)
    @points = points
  end
  def segment_count
    @points.size
  end
  def visit(visitor)
    @points.each {|p| visitor.line_to(p) }
  end
  def start  
    @points[0]
  end
end

class Path
  attr_reader :path, :start
  def initialize(startx, starty, path="")
    @path = path
    @start = Point.new(startx, starty)
  end
  def add(p,count=1)
    count.times {@path += p }
  end
  def segments
    @path.split(/\//)
  end
  def segment_count
    segments.size
  end
  def visit(visitor)
    cur = @start
    segments.each do |x|
      dir = x[0].chr
      len = x.slice(1, x.length-1).to_i
      if dir == "e"
        cur = cur.translate(len, 0)
      elsif dir == "n"
        cur = cur.translate(0, len)
      elsif dir == "w"
        cur = cur.translate(-len, 0)
      elsif dir == "s"
        cur = cur.translate(0, -len)
      else
        raise "Unrecognized direction " + dir.to_s + " in segment " + x.to_s
      end
      visitor.line_to(cur)
    end
  end
  def nethack(size=Nethack::DEFAULT_SIZE)
    n = Nethack.new(@start, size)
    visit(n)
    return n.render
  end
  def to_s
    @path
  end
end

class Nethack
  DEFAULT_SIZE=20
  def initialize(start,size)
    @start = start
    @map = Array.new(size)
    @map.each_index {|x| @map[x] = Array.new(size, ".") }
    @prev = @start
  end
  def line_to(current)
    @prev.lineto(current).each {|pt| @map[pt.y/100][pt.x/100] = "X" }
    @prev = current
  end
  def thing(t)
    puts "#{(t.location.y/100)},#{((@map.size-1) - (t.location.x/100))} -> #{Dictionary.get.thing_for_type_id(t.type_id).symbol}"
    @map[t.location.y/100][(@map.size-1) - (t.location.x/100)] = Dictionary.get.thing_for_type_id(t.type_id).symbol
  end
  def render
    res = ""
    @map.each_index do |x|
      @map[x].each_index do 
        |y| res << @map[@map.size-1-x][y-1] + " " 
      end
      res << "\n"
    end
    res
  end
end

if __FILE__ == $0
   file = ARGV.include?("-f") ? ARGV[ARGV.index("-f") + 1] : "../test_wads/simple.wad"
  w = Wad.new(ARGV.include?("-v"))
  w.read(file)
  w.lumps.each do |lump|
    puts lump.name + " (" + lump.size.to_s + " bytes)"
    lump.items.each { |t| puts " - " + t.to_s }
  end
end

