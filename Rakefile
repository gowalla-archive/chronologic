require "bundler"
Bundler.setup

require "rspec/core/rake_task"
Rspec::Core::RakeTask.new(:spec)

gemspec = eval(File.read("chronologic.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["chronologic.gemspec"] do
  system "gem build chronologic.gemspec"
  system "gem install chronologic-#{Chronologic::VERSION}.gem"
end




#load 'tasks/redis.rake'
#require 'rake/testtask'
#
#def command?(command)
#  system("type #{command} > /dev/null 2>&1")
#end
#
#task :default => :test
#
#desc "Run the test suite"
#task :test do
#  rg = command?(:rg)
#  Dir['test/**/*_test.rb'].each do |f|
#    rg ? sh("rg #{f}") : ruby(f)
#  end
#end
#
#task :install => [ 'redis:install', 'dtach:install' ]
#
#desc "Push a new version to Gemcutter"
#task :publish do
#  require 'chronologic/version'
#  sh "gem build chronologic.gemspec"
#  sh "gem push chronologic-#{Chronologic::Version}.gem"
#  sh "git tag v#{Chronologic::Version}"
#  sh "git push origin v#{Chronologic::Version}"
#  sh "git push origin master"
#  sh "git clean -fd"
#  exec "rake pages"
#end