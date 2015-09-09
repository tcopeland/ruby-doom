#!/usr/local/bin/ruby

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = "ruby-doom"
  s.version = "0.9"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby-DOOM provides a scripting API for creating DOOM maps. It also provides higher-level APIs to make map creation easier."
  s.description = "A library for creating DOOM maps"
  s.files = ["lib/example.rb","lib/ruby-doom.rb"]
  s.files.concat ["README.md", "CHANGELOG", "LICENSE"]
  s.files.concat ["test_wads/simple.wad"]
  s.files.concat ["bitmaps/wiggly.bmp"]
  s.require_path = "lib"
  s.author = "Tom Copeland"
  s.license = 'MIT'
  s.bindir = 'bin'
  s.executables = 'ruby-doom'
  s.rubyforge_project = 'none'
  s.email = "tom@thomasleecopeland.com"
  s.homepage = "https://github.com/tcopeland/ruby-doom"
  s.add_development_dependency 'rake', '~> 10.1'
  s.add_development_dependency 'minitest', '~> 5.0'
  s.add_development_dependency 'byebug'
end
