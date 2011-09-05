require "hashie"
require "cassandra/0.7"
require "active_support/core_ext/module"
require "chronologic/cassandra_ext"

module Chronologic

  EXPLICIT_NULL_VALUE = '.:_null_:.'

  mattr_accessor :connection

  def self.schema
    Chronologic::Service::Schema
  end

  autoload :Event, "chronologic/event"

  module Service
    autoload :App, "chronologic/service/app"
    autoload :Feed, "chronologic/service/feed"
    autoload :Protocol, "chronologic/service/protocol"
    autoload :Schema, "chronologic/service/schema"
  end

  module Client
    autoload :Connection, "chronologic/client/connection"
    autoload :Event, 'chronologic/client/event'
    autoload :Object, 'chronologic/client/object'
    autoload :Fake, 'chronologic/client/fake'
  end

  class Exception < RuntimeError; end
  class NotFound < RuntimeError; end
  class Duplicate < RuntimeError; end
  class TimestampAlreadySet < RuntimeError; end
  class ServiceError < RuntimeError
    attr_reader :response

    def initialize(resp)
      @response = Hashie::Mash.new(resp)
      super("Chronologic service error: #{response.message}")
    end
  end

end
