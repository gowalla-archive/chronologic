# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "chronologic/version"

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

  s.add_dependency('cassandra')
  s.add_dependency('httparty')
  s.add_dependency('hashie')
  s.add_dependency('yajl-ruby', ["~> 0.7.7"])
  s.add_dependency('activesupport', ["~> 3.0.0"])
  s.add_dependency('i18n', ["~> 0.5.0"])
  s.add_dependency('sinatra', ["~> 1.0.0"])

  # HAX
  s.add_dependency('thrift', ['~> 0.6.0'])
  s.add_dependency('thrift_client', ['~> 0.6.3'])
  s.add_dependency('simple_uuid', ['~> 0.1.0'])
end

