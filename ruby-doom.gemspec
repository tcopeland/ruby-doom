#!/usr/local/bin/ruby

require 'rubygems'

#test 

spec = Gem::Specification.new do |s|
	s.name = "ruby-doom"
	s.version = "0.8"
	s.platform = Gem::Platform::RUBY
	s.summary = "Ruby-DOOM provides a scripting API for creating DOOM maps. It also provides higher-level APIs to make map creation easier."
	s.files = ["lib/example.rb","lib/doom.rb"]
	s.files.concat ["etc/README"]
	s.files.concat ["etc/CHANGELOG"]
	s.files.concat ["etc/LICENSE"]
	s.files.concat ["test_wads/simple.wad"]
	s.files.concat ["bitmaps/wiggly.bmp"]
	s.require_path = "lib"
	s.autorequire = "doom"
	s.author = "Tom Copeland"
	s.email = "tom@infoether.com"
	s.rubyforge_project = "ruby-doom"
	s.homepage = "http://ruby-doom.rubyforge.org/"	
end

 Gem::Builder.new(spec).build if $0 == __FILE__
