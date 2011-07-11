task :default => ['spec:chronologic', 'spec:functional']

require 'rspec/core/rake_task'

namespace :spec do
  RSpec::Core::RakeTask.new(:chronologic) do |t|
    t.pattern = FileList["spec/chronologic/**/*_spec.rb"]
    t.pattern.include("spec/*_spec.rb")
    t.pattern.exclude("spec/functional/*_spec.rb")
  end

  RSpec::Core::RakeTask.new(:functional) do |t|
    t.pattern = FileList["spec/functional/*_spec.rb"]
  end
end

require 'bundler'
Bundler::GemHelper.install_tasks
