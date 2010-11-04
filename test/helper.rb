require "rubygems"
require "minitest/spec"
require "rack/test"
require "webmock/test_unit"

MiniTest::Unit.autorun

require "chronologic"

class MiniTest::Unit::TestCase
  include WebMock::API

  def setup
    WebMock.disable_net_connect!
    WebMock.reset_webmock
  end

  def chronologic_schema
    schema = Chronologic::Schema.new
    schema.connection = Cassandra.new("Chronologic")
    schema.connection.clear_keyspace!
    schema
  end

  def simple_event
    Chronologic::Event.new.tap do |event|
      event.key = "checkin_1"
      event.timestamp = Time.now.utc
      event.data = {"type" => "checkin", "message" => "I'm here!"}
      event.objects = {"user" => "user_1", "spot" => "spot_1"}
      event.timelines = ["user_1", "spot_1"]
    end
  end

  def nested_event
    subevent = Chronologic::Event.new.tap do |event|
      event.key = "comment_1"
      event.timestamp = Time.now.utc
      event.data = {"type" => "comment", "message" => "Me too!"}
      event.objects = {"user" => "user_2", "checkin" => "checkin_1"}
      event.timelines = ["checkin_1"]
    end

    Chronologic::Event.new.tap do |event|
      event.key = "checkin_2"
      event.timestamp = Time.now.utc
      event.data = {"type" => "checkin", "message" => "I'm here!"}
      event.objects = {"user" => "user_1", "spot" => "spot_1"}
      event.timelines = ["user_1", "spot_1"]
      event.subevents = [subevent]
    end
  end

end
