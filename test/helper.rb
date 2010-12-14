require "pp"
require "rubygems"
require "minitest/spec"
require "rack/test"
require "webmock/test_unit"

MiniTest::Unit.autorun

require "chronologic"
require "cassandra/mock"

class MiniTest::Unit::TestCase
  include WebMock::API

  def setup
    Chronologic.connection = if ENV['CASSANDRA']
      Cassandra.new("Chronologic-Test")
    else
      Cassandra::Mock.new(
        'Chronologic', 
        File.join(File.dirname(__FILE__), 'storage-conf.xml')
      )
    end
    Chronologic.connection.clear_keyspace!

    WebMock.disable_net_connect!
    WebMock.reset_webmock
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
    Chronologic::Event.new.tap do |event|
      event.key = "comment_1"
      event.timestamp = Time.now.utc
      event.data = {"type" => "comment", "message" => "Me too!"}
      event.objects = {"user" => "user_2", "checkin" => "checkin_1"}
      event.timelines = ["checkin_1"]
    end
  end

end
