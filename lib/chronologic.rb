require "hashie"
require "active_support/core_ext/module"
require "chronologic/cassandra_ext"
require "multi_json"

module Chronologic

  mattr_accessor :connection

  def self.schema
    Chronologic::Service::Schema
  end

  autoload :Event, "chronologic/event"

  module Service
    autoload :App, "chronologic/service/app"
    autoload :Event, "chronologic/service/event"
    autoload :Feed, "chronologic/service/feed"
    autoload :ObjectlessFeed, "chronologic/service/objectless_feed"
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
      super
    end

    def inspect
      "#<Chronologic::ServiceError: #{response.exception_class} - #{response.message}>"
    end

    def to_s
      inspect
    end
  end

end
