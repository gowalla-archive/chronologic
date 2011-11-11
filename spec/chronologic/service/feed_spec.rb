require 'spec_helper'

describe Chronologic::Service::Feed do

  let(:schema) { Chronologic::Service::Schema::Memory.new }
  let(:protocol) { Chronologic::Service::Protocol }
  let(:feed) { subject.create("user_1_home") }
  subject { Chronologic::Service::Feed }

  it_behaves_like "a feed strategy"

  it "generates a feed for a timeline key" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    protocol.record("user_1", akk)
    protocol.record("spot_1", jp)

    event = simple_event

    protocol.subscribe("user_1_home", "user_1")
    protocol.publish(event)

    ["user_1", "spot_1", "user_1_home"].each do |t|
      feed = subject.create(t).items
      feed[0].data.should == event.data
      feed[0].objects["user"].should == protocol.schema.object_for("user_1")
      feed[0].objects["spot"].should == protocol.schema.object_for("spot_1")
    end
  end

  it "generates a feed for a timeline key, fetching nested timelines" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    jp = {"name" => "Juan Pelota's"}
    protocol.record("user_1", akk)
    protocol.record("user_2", sco)
    protocol.record("spot_1", jp)

    event = Chronologic::Service::Event.new
    event.key = "checkin_1111"
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    protocol.subscribe("user_1_home", "user_1")
    event = protocol.publish(event)

    event = Chronologic::Service::Event.new
    event.key = "comment_1111"
    event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_2"}
    event.timelines = ["checkin_1111"]
    protocol.publish(event)

    event = Chronologic::Service::Event.new
    event.key = "comment_2222"
    event.data = {"type" => "comment", "message" => "Great!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_1"}
    event.timelines = ["checkin_1111"]
    protocol.publish(event)

    protocol.schema.timeline_events_for("checkin_1111").values.should include(event.key)
    subevents = subject.create("user_1_home", :fetch_subevents => true).items.first.subevents
    subevents.last.data.should == event.data
    subevents.first.objects["user"].should == protocol.schema.object_for("user_2")
    subevents.last.objects["user"].should == protocol.schema.object_for("user_1")
  end

  it "fetches events for one or more timelines" do
    events = [simple_event]
    events << simple_event.tap do |e|
      e.key = "checkin_2"
      e.data['message'] = "I'm over there!"
    end
    events << simple_event.tap do |e|
      e.key = "checkin_3"
      e.data['message'] = "I'm way over there!"
    end
    events << simple_event.tap do |e|
      e.key = "checkin_4"
      e.data['message'] = "I'm over here!"
      e.timelines = ["user_2"]
    end
    events << simple_event.tap do |e|
      e.key = "checkin_5"
      e.data['message'] = "I'm nowhere!"
      e.timelines = ["user_2"]
    end
    events.each { |e| protocol.publish(e) }

    events = feed.fetch_timelines(["user_1", "user_2"])

    events.length.should == 5
    events.each { |e| e.should be_instance_of(Chronologic::Service::Event) }
  end

  describe "feed reification" do

    subject { described_class.create("user_1_home") }

    it "constructs a feed from multiple events" do
      events = 5.times.map { simple_event }

      timeline = subject.reify_timeline(events)

      timeline.length.should == 5
    end

    it "constructs a feed from events with subevents" do
      events = [simple_event, nested_event]

      timeline = subject.reify_timeline(events)

      timeline.length.should == 1
      timeline.first.subevents.should == [events.last]
    end

    it "constructs a feed from events with sub-subevents" do
      events = [simple_event, nested_event]

      events << simple_event.tap do |e|
        e.key = "checkin_2"
        e.data['message'] = "I'm over there"
      end

      events << simple_event.tap { |e| e.key = "grouping_1" }
      events << simple_event.tap do |e|
        e.key = "checkin_3"
        e.parent = "grouping_1"
        e.timelines << "grouping_1"
      end
      events << simple_event.tap do |e|
        e.key = "comment_2"
        e.parent = "checkin_3"
        e.timelines << "checkin_3"
      end

      timeline = subject.reify_timeline(events)

      timeline.length.should == 3
      timeline[0].subevents.length.should == 1
      timeline[1].subevents.length.should == 0
      timeline[2].subevents.length.should == 1
      timeline[2].subevents[0].subevents.length.should == 1
    end

  end

  it "fetches objects associated with an event" do
    protocol.record("spot_1", {"name" => "Juan Pelota's"})
    protocol.record("user_1", {"name" => "akk"})
    protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    populated_event = feed.fetch_objects([event]).first

    populated_event.objects["test"].length.should == 2
    populated_event.objects["user"].should be_kind_of(Hash)
    populated_event.objects["spot"].should be_kind_of(Hash)
  end


end
