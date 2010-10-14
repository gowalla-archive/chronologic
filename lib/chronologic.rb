require 'chronologic/client'
require 'chronologic/connection'
require 'chronologic/server'
require 'chronologic/version'

require "active_support/core_ext/module"

module Chronologic

  VERSION = "0.1.0"

  mattr_accessor :connection
  mattr_accessor :client

end
