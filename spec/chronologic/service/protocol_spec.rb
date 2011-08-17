require 'spec_helper'

describe Chronologic::Service::Protocol do

  let(:protocol) { Chronologic::Service::Protocol }

  it "records an entity" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    protocol.record("user_1", akk)
    protocol.record("spot_1", jp)

    hsh = {"user_1" => akk, "spot_1" => jp}
    protocol.schema.object_for(["user_1", "spot_1"]).should == hsh
  end

  it "unrecords an entity" do
    protocol.record("user_1", {"name" => "akk"})
    protocol.unrecord("user_1")

    protocol.schema.object_for("user_1").should == Hash.new
  end

  it "subscribes a subscriber key to a timeline key and populates a timeline" do
    event = simple_event

    protocol.publish(event)
    protocol.subscribe("user_1_home", "user_1")

    protocol.schema.subscribers_for("user_1").should == ["user_1_home"]
    protocol.schema.timeline_events_for("user_1_home").values.should include(event.key)
  end

  it "subscribes a subscriber key to a timeline key with no backfill" do
    event = simple_event

    protocol.publish(event)
    protocol.subscribe("user_1_home", "user_2", 'user_1', false)

    protocol.schema.subscribers_for("user_2").should == ["user_1_home"]
    protocol.schema.timeline_events_for("user_1_home").length.should == 0
  end

  it "unsubscribes a subscriber key from a timeline key" do
    event = simple_event

    protocol.publish(event)
    protocol.subscribe("user_1_home", "user_1")
    protocol.unsubscribe("user_1_home", "user_1")

    protocol.schema.subscribers_for("user_1").should == []
    protocol.schema.timeline_events_for("user_1_home").values.should == []
  end

  it 'checks whether a feed and a user are connected' do
    protocol.subscribe('user_1_home', 'user_2', 'user_1')
    protocol.subscribe('user_3_home', 'user_2') # No backlink, no connection

    protocol.connected?('user_2', 'user_1').should == true
    protocol.connected?('user_2', 'user_3').should == false
  end

  it "publishes an event to one or more timeline keys" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    protocol.subscribe("user_1_home", "user_1")
    protocol.publish(event)

    fetched = Chronologic::Event.load_from_columns(protocol.schema.event_for(event.key))
    fetched["timestamp"].iso8601.should == event.timestamp.iso8601
    fetched["data"].should == event.data
    fetched["objects"].should == event.objects
    protocol.schema.timeline_events_for("user_1_home").values.should include(event.key)
    event.timelines.each do |t|
      protocol.schema.timeline_events_for(t).values.should include(event.key)
    end
  end

  it "publishes an event without fanout" do
    event = simple_event
    protocol.subscribe("user_1_home", "user_1")
    uuid = protocol.publish(event, false)

    protocol.schema.timeline_events_for("user_1_home").should_not include(event.key)
  end

  it "publishes an event twice without duplicates" do
    event = simple_event
    protocol.publish(event, false)
    protocol.publish(event, false)

    protocol.schema.timeline_events_for("user_1").length.should == 1
  end

  it "publishes an event with an existing key updates the existing event" do
    event = simple_event
    protocol.publish(event, false)
    event.timelines << "foo_1"
    protocol.publish(event, false)

    protocol.schema.timeline_events_for("user_1").length.should == 1
    protocol.schema.event_for(event.key).should == event.to_columns
    event.published?.should == true
  end

  it "unpublishes an event from one or more timeline keys" do
    event = simple_event

    protocol.subscribe("user_1_home", "user_1")
    uuid = protocol.publish(event)
    protocol.unpublish(event)

    protocol.schema.event_for(event.key).should == Hash.new
    protocol.schema.timeline_events_for("user_1_home").should_not include(event.key)
    event.timelines.each do |t|
      protocol.schema.timeline_events_for(t).should_not include(event.key)
    end
  end

  # AKK: no test for Protocol.feed since it delegates everything to Feed

  it "fetches one event" do
    event = simple_event
    protocol.publish(event, false)
    protocol.fetch_event(event.key).key.should eq(event.key)
  end

  it "fetches an event with objects" do
    user = {'username' => 'ak'}
    spot = {'name' => 'JP'}
    protocol.record('user_1', user)
    protocol.record('spot_1', spot)

    event = simple_event
    protocol.publish(simple_event, false)

    protocol.fetch_event(event.key).objects['user'].should eq(user)
    protocol.fetch_event(event.key).objects['spot'].should eq(spot)
  end

  it "fetches an event with subevents" do
    event = simple_event
    protocol.publish(event, false)

    nested = nested_event
    protocol.publish(nested, false)

    protocol.fetch_event(event.key).subevents.first.key.should eq(nested.key)
  end

  it "fetches an event with subevents with objects" do
    user = {'username' => 'ak'}
    user2 = {'username' => 'ka'}
    spot = {'name' => 'JP'}
    protocol.record('user_1', user)
    protocol.record('user_2', user2)
    protocol.record('spot_1', spot)

    event = simple_event
    protocol.publish(event, false)

    nested = nested_event
    protocol.publish(nested, false)

    event = protocol.fetch_event(event.key)
    event.objects['user'].should eq(user)
    event.objects['spot'].should eq(spot)
    event.subevents.first.objects['user'].should eq(user2)
  end

  it "updates an event's attributes" do
    event = simple_event
    protocol.publish(event, false)
    event.data['hotness'] = "It's so new!"

    protocol.update_event(event)
    protocol.fetch_event(event.key).data['hotness'].should eq("It's so new!")
  end

  it "updates an event's attributes and writes to all timelines" do
    event = simple_event
    protocol.publish(event, false)
    event.timelines << 'testify_1'

    protocol.update_event(event, true)
    protocol.fetch_event(event.key).timelines.should include('testify_1')
    protocol.schema.timeline_events_for('testify_1').values.should include(event.key)
  end

  it "counts item in a feed" do
    populate_timeline
    protocol.feed_count("user_1_home").should == 10
  end

end

