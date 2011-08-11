# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "chronologic"

Gem::Specification.new do |s|
  s.name     = 'chronologic'
  s.version  = Chronologic::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors  = ["Adam Keys", "Scott Raymond"]
  s.email    = 'ak@gowalla.com'
  s.homepage = 'http://github.com/gowalla/chronologic'
  s.summary     = "Chronologic is a database for activity feeds."
  s.description = "Chronologic uses Cassandra to fetch and store activity feeds. Quickly."

  s.rubyforge_project = "chronologic"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('cassandra', ["~> 0.11.0"])
  s.add_dependency('httparty', ["~> 0.7.8"])
  s.add_dependency('hashie', ["~> 1.1.0"])
  s.add_dependency('will_paginate', ["~> 3.0.0"])
  s.add_dependency('yajl-ruby', ["~> 0.8.2"])
  s.add_dependency('activesupport', ["~> 3.0.0"])
  s.add_dependency('i18n', ["~> 0.5.0"])
  s.add_dependency('sinatra', ["~> 1.0.0"])
  s.add_dependency('activemodel', ['~> 3.0.0'])

  # HAX
  s.add_dependency('thrift', ['~> 0.5.0'])
  s.add_dependency('thrift_client', ['~> 0.6.0'])
end

