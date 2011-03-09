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
      Chronologic::Schema.write_opts = {
        :consistency => Cassandra::Consistency::ONE
      }
      Cassandra.new("Chronologic-Test")
    else
      Cassandra::Mock.new(
        'Chronologic', 
        File.join(File.dirname(__FILE__), 'storage-conf.xml')
      )
    end
    Chronologic.connection.clear_keyspace!

    WebMock.disable_net_connect!
    WebMock.reset!
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
      event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1"}
      event.objects = {"user" => "user_2", "checkin" => "checkin_1"}
      event.timelines = ["checkin_1"]
    end
  end

  def populate_timeline
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("spot_1", jp)

    uuids = []
    %w{sco jc am pb mt rm ak ad rs bf}.each_with_index do |u, i|
      record = {"name" => u}
      key = "user_#{i}"
      @protocol.record(key, record)

      @protocol.subscribe("user_1_home", "user_#{i}")

      event = simple_event
      event.key = "checkin_#{i}"
      event.objects["user"] = key
      event.timelines = [key, "spot_1"]
      uuids << @protocol.publish(event)
    end

    return uuids
  end
end
