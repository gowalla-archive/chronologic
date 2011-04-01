require "hashie"
require "cassandra/0.6"
require "active_support/core_ext/module"

module Chronologic

  mattr_accessor :connection

  def self.schema
    Chronologic::Schema
  end

  VERSION = '0.8.2'

  autoload :Schema, "chronologic/schema"
  autoload :Protocol, "chronologic/protocol"
  autoload :Feed, "chronologic/feed"
  autoload :Event, "chronologic/event"
  autoload :Service, "chronologic/service"
  autoload :Client, "chronologic/client"
  autoload :Publisher, "chronologic/publisher"
  autoload :Record, "chronologic/record"
  autoload :Subscriber, "chronologic/subscriber"

  class Exception < RuntimeError; end
  class ServiceError < RuntimeError 
    attr_reader :response

    def initialize(resp)
      @response = Hashie::Mash.new(resp)
      super("Chronologic service error: #{response.message}")
    end

  end

end
