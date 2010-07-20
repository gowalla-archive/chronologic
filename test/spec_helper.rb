require "bundler"
Bundler.setup

require "rspec"
require "chronologic"

Rspec.configure do |config|
#  config.include NewGem::Spec::Matchers
end