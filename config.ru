#\ -p 4567 -s thin

$: << File.expand_path('../lib', __FILE__)

require 'chronologic'
require 'chronologic/server'

use Rack::Lint
use Rack::ShowExceptions
run Chronologic::Server.new