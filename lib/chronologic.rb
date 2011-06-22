require "hashie"
require "cassandra/0.7"
require "active_support/core_ext/module"
require "chronologic/cassandra_ext"

module Chronologic

  mattr_accessor :connection

  def self.schema
    Chronologic::Schema
  end

  VERSION = '0.9.1'

  autoload :Schema, "chronologic/schema"
  autoload :Feed, "chronologic/feed"
  autoload :Event, "chronologic/event"
  autoload :Publisher, "chronologic/publisher"
  autoload :Record, "chronologic/record"
  autoload :Subscriber, "chronologic/subscriber"

  module Service
    autoload :App, "chronologic/service/app"
    autoload :Protocol, "chronologic/service/protocol"
  end

  module Client

    autoload :Connection, "chronologic/client/connection"
    autoload :Event, 'chronologic/client/event'
    autoload :Object, 'chronologic/client/object'

  end

  class Exception < RuntimeError; end
  class ServiceError < RuntimeError 
    attr_reader :response

    def initialize(resp)
      @response = Hashie::Mash.new(resp)
      super("Chronologic service error: #{response.message}")
    end

  end

end
