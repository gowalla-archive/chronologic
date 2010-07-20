#!/usr/bin/env ruby

$: << File.expand_path('../lib', __FILE__)

require 'chronologic'
require 'chronologic/server'

# if ENV['CHRONOLOGIC_CONFIG'] && ::File.exists?(::File.expand_path(ENV['CHRONOLOGIC_CONFIG']))
#   load ::File.expand_path(ENV['CHRONOLOGIC_CONFIG'])
# end

use Rack::Lint
use Rack::ShowExceptions
run Chronologic::Server.new