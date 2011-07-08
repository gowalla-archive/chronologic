require 'spec_helper'

describe Chronologic::Event do

  let(:event) do
    Chronologic::Event.new.tap do |e|
      e.key = 'event_1'
      e.timestamp = Time.now
      e.data = {"foo" => {"one" => "two"}}
      e.objects = {"user" => "user_1", "spot" => "spot_1"}
      e.timelines = ["user_1", "sxsw"]
    end
  end

  it "serializes structured data columns" do
    event.to_columns["data"].should == JSON.dump(event.data)
    event.to_columns["objects"].should == JSON.dump(event.objects)
    event.to_columns["timelines"].should == JSON.dump(event.timelines)
  end

  it "loads an event fetched from Cassandra" do
    new_event = Chronologic::Event.load_from_columns(event.to_columns)
    new_event.timestamp.to_s.should == event.timestamp.to_s
    new_event.data.should == event.data
    new_event.objects.should == event.objects
    new_event.timelines.should == event.timelines
  end

  it "loads an empty event" do
    empty_event = Chronologic::Event.load_from_columns({})
    empty_event.timestamp.should be_nil
    empty_event.data.should == Hash.new
    empty_event.objects.should == Hash.new
    empty_event.timelines.should == Array.new
  end

  it "serializes for HTTP transport" do
    event.to_transport["data"].should == JSON.dump(event.data)
    event.to_transport["objects"].should == JSON.dump(event.objects)
    event.to_transport["timelines"].should == JSON.dump(event.timelines)
    event.to_transport["key"].should == event.key
  end

  it "knows whether it is a subevent" do
    nested_event.subevent?.should == true
  end

  it "knows its parent event" do
    nested_event.parent.should == "checkin_1"
  end

  it "sets its parent event" do
    event = simple_event
    event.parent = "highlight_1"
    event.parent.should == "highlight_1"
  end

  it "is unpublished by default" do
    event.published?.should == false
  end

  it "toggles published state" do
    event.published!
    event.published?.should == true
  end

  it "returns children as CL::Event objects" do
    subevent = {
      "key" => "bar_1",
      "timestamp" => Time.now.utc,
      "data" => {"bar" => "herp"}
    }

    event = Chronologic::Event.new(
      :key => "foo_1", 
      :timestamp => Time.now.utc, 
      :data => {"foo" => "derp"}, 
      :subevents => [subevent]
    )
    event.children.should == [Chronologic::Event.new(subevent)]
  end
end

