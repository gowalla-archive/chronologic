$LOAD_PATH.unshift 'lib'
require 'chronologic/version'

Gem::Specification.new do |s|
  s.name              = "chronologic"
  s.version           = Chronologic::Version
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "Activity feeds as a service."
  s.homepage          = "http://github.com/gowalla/chronologic"
  s.email             = "sco@gowalla.com"
  s.authors           = [ "Scott Raymond" ]

  s.files             = %w( config.ru init.rb LICENSE Rakefile README.md )
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("examples/**/*")
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("tasks/**/*")
  s.files            += Dir.glob("test/**/*")
  s.executables       = [ "chronologic-web" ]

  s.extra_rdoc_files  = [ "LICENSE", "README.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "net-http-persistent", ">= 1.2.4"
  s.add_dependency "cassandra", ">= 0.9.0"
  s.add_dependency "yajl-ruby", ">= 0.7.7"
  s.add_dependency "sinatra", ">= 1.0.0"
  #s.add_dependency "vegas", ">= 0.1.7"
  #s.add_dependency "rack", ">= 1.2.1"

  s.description = <<description
    Chronologic is a library for managing Activity Streams (aka News
    Feeds or Timelines). Like Twitter, or just about any social network.
    It uses Cassandra.
description
end