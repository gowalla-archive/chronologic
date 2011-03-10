require "helper"

describe Chronologic::Event do

  before do
    @event = Chronologic::Event.new
    @event.timestamp = Time.now
    @event.data = {"foo" => {"one" => "two"}}
    @event.objects = {"user" => "user_1", "spot" => "spot_1"}
    @event.timelines = ["user_1", "sxsw"]
  end

  it "serializes structured data columns" do
    @event.to_columns["data"].must_equal JSON.dump(@event.data)
    @event.to_columns["objects"].must_equal JSON.dump(@event.objects)
    @event.to_columns["timelines"].must_equal JSON.dump(@event.timelines)
  end

  it "loads an event fetched from Cassandra" do
    new_event = Chronologic::Event.load_from_columns(@event.to_columns)
    new_event.data.must_equal @event.data
    new_event.objects.must_equal @event.objects
    new_event.timelines.must_equal @event.timelines
  end

  it "serializes for HTTP transport" do
    @event.to_transport["data"].must_equal JSON.dump(@event.data)
    @event.to_transport["objects"].must_equal JSON.dump(@event.objects)
    @event.to_transport["timelines"].must_equal JSON.dump(@event.timelines)
    @event.to_transport["key"].must_equal @event.key
  end

  it "knows whether it is a subevent" do
    nested_event.subevent?.must_equal true
  end

  it "knows its parent event" do
    nested_event.parent.must_equal "checkin_1"
  end

  it "sets its parent event" do
    event = simple_event
    event.parent = "highlight_1"
    event.parent.must_equal "highlight_1"
  end
end

