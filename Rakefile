require "rake/testtask"

  def name
    @name ||= Dir['*.gemspec'].first.split('.').first
  end

  def version
    line = File.read("lib/#{name}.rb")[/^\s*VERSION\s*=\s*.*/]
    line.match(/.*VERSION\s*=\s*['"](.*)['"]/)[1]
  end

  def date
    Date.today.to_s
  end

  def rubyforge_project
    name
  end

  def gemspec_file
    "#{name}.gemspec"
  end

  def gem_file
    "#{name}-#{version}.gem"
  end

  def replace_header(head, header_name)
    head.sub!(/(\.#{header_name}\s*= ').*'/) { "#{$1}#{send(header_name)}'"}
  end

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
end

desc "Generate RCov test coverage and open in your browser"
task :coverage do
  sh "rm -fr coverage"
  sh "rcov test/test_*.rb"
  sh "open coverage/index.html"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/#{name}.rb"
end

