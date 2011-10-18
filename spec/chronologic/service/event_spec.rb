require 'spec_helper'

shared_examples_for "a CL event" do

  let(:nested_event) do
    described_class.from_attributes(
      :key => "comment_1",
      :data => {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1"},
      :objects => {"user" => "user_2"},
      :timelines => ["checkin_1"]
    )
  end

  it "knows whether it is a subevent" do
    nested_event.subevent?.should == true
  end

  it "knows its parent event" do
    nested_event.parent.should == "checkin_1"
  end

  it "sets its parent event" do
    event = nested_event
    event.parent = "highlight_1"
    event.parent.should == "highlight_1"
  end

  it "returns children as CL::Event objects" do
    subevent = {
      "key" => "bar_1",
      "data" => {"bar" => "herp"}
    }

    event = described_class.from_attributes(
      :key => "foo_1", 
      :data => {"foo" => "derp"}, 
      :subevents => [subevent]
    )
    event.children.should eq([described_class.from_attributes(subevent)])
  end

  it "flags an empty event" do
    subject.data = {}
    subject.should be_empty
  end

end

describe Chronologic::Service::Event do
  it_behaves_like "a CL event"

  subject do
    described_class.from_attributes(
      :key => "event_1",
      :data => {"foo" => {"one" => "two"}},
      :objects => {"user" => "user_1", "spot" => "spot_1"},
      :timelines => ["user_1", "sxsw"],
      :token => [Time.now.tv_sec, "event_1"].join(':')
    )
  end

  it "serializes structured data columns" do
    subject.to_columns["data"].should == MultiJson.encode(subject.data)
    subject.to_columns["objects"].should == MultiJson.encode(subject.objects)
    subject.to_columns["timelines"].should == MultiJson.encode(subject.timelines)
  end

  it "loads an event fetched from Cassandra" do
    new_event = described_class.from_columns(subject.to_columns)
    new_event.token.should == subject.token
    new_event.data.should == subject.data
    new_event.objects.should == subject.objects
    new_event.timelines.should == subject.timelines
  end

  it "loads an empty event" do
    empty_event = Chronologic::Event.load_from_columns({})
    empty_event.token.should == ''
    empty_event.data.should == Hash.new
    empty_event.objects.should == Hash.new
    empty_event.timelines.should == Array.new
  end

  it "encodes for sending back to HTTP clients" do
    subject.to_client_encoding["data"].should == subject.data
    subject.to_client_encoding["objects"].should == subject.objects
    subject.to_client_encoding["timelines"].should == subject.timelines
    subject.to_client_encoding["subevents"].should == subject.subevents
    subject.to_client_encoding["key"].should == subject.key
  end

  it "populates token" do
    subject.key = "thingoid_1"
    subject.set_token
    subject.token.should match(/thingoid_1/)
  end

  it "populates token with a forced timestamp" do
    subject.key = "thingoid_1"
    subject.set_token(123)
    subject.token.should eq("123_thingoid_1")
  end

end
