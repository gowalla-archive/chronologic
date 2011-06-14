task :default => [:spec]

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = FileList["spec/**/*_spec.rb"]
end

require 'bundler'
Bundler::GemHelper.install_tasks

