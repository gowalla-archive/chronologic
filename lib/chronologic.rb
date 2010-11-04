require "cassandra"

module Chronologic

  VERSION = '0.2.0'

  autoload :Schema, "chronologic/schema"
  autoload :Protocol, "chronologic/protocol"
  autoload :Event, "chronologic/event"
  autoload :Service, "chronologic/service"
  autoload :Client, "chronologic/client"
  autoload :Publisher, "chronologic/publisher"
  autoload :Record, "chronologic/record"
  autoload :Subscriber, "chronologic/subscriber"

  class Exception < RuntimeError; end

end
