$: << File.expand_path('../lib', __FILE__)

require 'yaml'
require 'chronologic'
require 'chronologic/server'

config = if ENV['CHRONOLOGIC_CONFIG']
  open(ENV['CHRONOLOGIC_CONFIG']) {|f| YAML.load(f) }[ENV['RACK_ENV']]
else
  nil
end

#use Rack::Lint
#use Rack::ShowExceptions
run Chronologic::Server.new :chronologic_options => config