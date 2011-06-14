task :default => [:test, :spec]

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/test_*.rb"]
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = FileList["spec/**/*_spec.rb"]
end

require 'bundler'
Bundler::GemHelper.install_tasks

