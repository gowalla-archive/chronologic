require 'spec_helper'

describe Chronologic::Service::Schema::Cassandra do 

  let(:protocol) { Chronologic::Service::Protocol }

  subject do
    Chronologic::Service::Schema::Cassandra
  end

  it_behaves_like "a CL schema"

  it "counts items in a timeline" do
    pending("Cheating on counts for a while")
    10.times { |i| subject.create_timeline_event("_global", i.to_s, "junk") }
    subject.timeline_count("_global").should == 10
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

    events = subject.fetch_timelines(["user_1", "user_2"])

    events.length.should == 5
    events.each { |e| e.should be_instance_of(Chronologic::Service::Event) }
  end

  it "fetches objects associated with an event" do
    protocol.record("spot_1", {"name" => "Juan Pelota's"})
    protocol.record("user_1", {"name" => "akk"})
    protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    populated_event = subject.fetch_objects([event]).first

    populated_event.objects["test"].length.should == 2
    populated_event.objects["user"].should be_kind_of(Hash)
    populated_event.objects["spot"].should be_kind_of(Hash)
  end

  describe "feed reification" do

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

  def raise_on_multiget
    double = Object.new
    class <<double
      def multi_get(*args)
        raise "multi_get should not get called"
      end
    end

    Chronologic.connection = double
  end
end

