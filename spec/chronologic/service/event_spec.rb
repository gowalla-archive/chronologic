require 'spec_helper'

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
    empty_event = described_class.load_from_columns({})
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
