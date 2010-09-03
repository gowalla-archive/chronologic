#require "bundler"
#Bundler.setup

require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$LOAD_PATH.unshift 'lib'
require 'chronologic/version'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name        = "chronologic"
    gem.summary     = "Activity feeds as a service."
    gem.description = "Chronologic is a library for managing Activity Streams (aka News Feeds or Timelines). Like Twitter, or just about any social network. It uses Cassandra."
    gem.version     = Chronologic::Version
    gem.date        = Time.now.strftime('%Y-%m-%d')
    gem.homepage    = "http://github.com/gowalla/chronologic"
    gem.email       = "sco@gowalla.com"
    gem.authors     = [ "Scott Raymond" ]
                   
    gem.files  = %w( config.ru init.rb LICENSE Rakefile README.md )
    gem.files += Dir.glob("examples/**/*")
    gem.files += Dir.glob("lib/**/*")
    gem.files += Dir.glob("tasks/**/*")
    gem.files += Dir.glob("test/**/*")

    gem.extra_rdoc_files = [ "LICENSE", "README.md" ]
    gem.rdoc_options     = ["--charset=UTF-8"]

    gem.add_dependency "cassandra", ">= 0.8.2"
    gem.add_dependency "patron", ">= 0.4.6"
    gem.add_dependency "yajl-ruby", ">= 0.7.7"
    gem.add_dependency "sinatra", ">= 1.0.0"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :test => :check_dependencies
task :default => :test

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Chronologic #{Chronologic::Version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
