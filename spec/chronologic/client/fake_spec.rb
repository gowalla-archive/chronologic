require 'spec_helper'

describe Chronologic::Client::Fake do

  def valid_event_hash
    {
      'key' => 'event_1',
      'timelines' => [],
      'objects' => {},
      'subevents' => [],
      'data' => {}
    }
  end

  def valid_event
    Chronologic::Client::Event.from_attributes(valid_event_hash)
  end

  describe "#record" do
    it "stores an object" do
      subject.record("thing_1", {"thingy" => "thingoid"})
      subject.objects.should include("thing_1" => {"thingy" => "thingoid"})
    end

    it "raises an exception if data is not a hash" do
      expect { subject.record("thing_1", Array.new) }.to raise_exception(ArgumentError)
    end
  end

  describe "#unrecord" do
    it "removes a stored object" do
      subject.record("thing_1", {"thingy" => "thingoid"})
      subject.unrecord("thing_1")
      subject.objects.should be_empty
    end
  end

  describe "#subscribe" do

    it "creates a subscription" do
      subject.subscribe("user_akk", "user_mt_feed", "user_mt")
      subject.subscribers.should include("user_akk" => {"user_mt_feed" => "user_mt"})
    end

    it "backfills the specified timeline"

  end

  describe "#unsubscribe" do

    it "removes a subscription" do
      subject.subscribe("user_akk", "user_mt_feed", "user_mt")
      subject.unsubscribe("user_akk", "user_mt_feed")
      subject.subscribers["user_akk"].should be_empty
    end

    it "removes unsubscribed entries from the timeline"

  end

  describe "#connected?" do

    it "checks if a subscriber is connected with a backlink to a consumer" do
      subject.subscribe("user_akk", "user_mt_feed", "user_mt")
      subject.should be_connected("user_akk", "user_mt")
    end

  end

  describe "#publish" do

    it "creates a new event" do
      event = valid_event
      subject.publish(event)
      subject.events.values.should include(event)
    end

    it "writes the event to each specified timeline" do
      event = valid_event
      event.timelines = ['foo']

      subject.publish(event)
      subject.timelines['foo'].values.should include('event_1')
    end

    it "writes the event to subscribed timelines" do
      subject.subscribe('user_1', 'user_2_feed')
      event = valid_event
      event.timelines = ['user_1']
      subject.publish(event)
      subject.timelines['user_2_feed'].values.should include(event.key)
    end

    it "returns a CL key instead of a URL" do
      event = valid_event
      subject.publish(event).should eq(event.key)
    end

    it "raises an exception if event is not a Chronologic::Event" do
      expect { subject.publish("string") }.to raise_exception(ArgumentError)
    end
  end

  describe "#fetch" do

    it "returns nil if an event isn't found" do
      subject.fetch('gobbeldygook').should be_nil
    end

    it "retrieves an event" do
      event = valid_event
      subject.publish(event)
      subject.fetch(event.key).should eq(event)
    end

    it "copies retrieved events" do
      event = valid_event
      subject.publish(event)
      subject.fetch(event.key).should_not equal(event)
    end

    it "populates objects on fetched events" do
      object = {"thingy" => '1234'}
      subject.record('object_1', object)

      event = valid_event.tap do |e|
        e.key = 'event_1'
        e.objects = {'gizmos' => ['object_1']}
      end
      subject.publish(event)

      subject.fetch(event.key).objects['gizmos']['object_1'].should eq(object)
    end

    it "not return a Chronologic::Event" do
      event = valid_event
      subject.publish(event)

      subject.fetch(event.key).class.should_not be_kind_of(Chronologic::Event)
    end

    it "fetches subevents on fetched events" do
      event = valid_event
      subject.publish(event)

      subevent = valid_event.tap do |e|
        e.key = 'subevent_1'
        e.timelines = [event.key]
      end
      subject.publish(subevent)

      subject.fetch(event.key).subevents.should include(subevent)
    end

    it "populates objects on fetched subevents" do
      event = valid_event
      subject.publish(event)

      subevent = valid_event.tap do |e|
        e.key = 'subevent_1',
        e.timelines = [event.key],
        e.objects = {'gizmos' => ['object_1']}
      end
      subject.publish(subevent)

      object = {"thingy" => "weird"}
      subject.record('object_1', object)

      fetched = subject.fetch(event.key).subevents.first
      fetched.objects['gizmos'].should include('object_1' => object)
    end

  end

  describe "#update" do

    it "rewrites an existing event" do
      event = valid_event
      subject.publish(event)

      updated = event.dup
      updated.data = {"happy" => "yep!"}
      subject.update(updated)

      subject.fetch(event.key).should eq(updated)
    end

  end

  describe "#timeline" do

    let(:events) do
      10.times.map do |i|
        event = valid_event.tap do |e|
          e.key = "event_#{i}",
          e.timelines = ['home']
        end
      end
    end

    before(:each) { events.each { |e| subject.publish(e) } }

    it "fetches a page of events on a timeline" do
      pending("Get this working with token-based timelines")
      feed = subject.timeline('home')

      feed['count'].should eq(10)
      feed['items'].should eq(events)
    end

    it "fetches the specified number of events" do
      pending("Get this working with token-based timelines")
      feed = subject.timeline('home', 'per_page' => 5)

      feed['count'].should eq(10)
      feed['items'].length.should eq(5)
    end

    it "fetches from a page offset" do
      pending("Get this working with token-based timelines")
      token = subject.timeline('home', 'per_page' => 5)['next_page']
      feed = subject.timeline('home', 'per_page' => 5, 'page' => token)

      feed['count'].should eq(10)
      feed['items'].length.should eq(5)
      feed['items'].should eq(events.last(5))
    end

    it "fetches objects on events" do
      object = {"doneness" => "so close"}
      subject.record('object_1', object)

      event = valid_event.tap do |e|
        e.key = 'event_100',
        e.timelines = ['with_object'],
        e.objects = {"object" => ['object_1']}
      end
      subject.publish(event)

      feed = subject.timeline('with_object')
      feed['items'].first.objects["object"].should eq({"object_1" => object})
    end

    it "fetches subevents on events" do
      parent = valid_event.tap do |e|
        e.key = 'event_1'
        e.timelines = ['with_subevent']
      end
      subevent = valid_event.tap do |e|
        e.key = 'event_2'
        e.timelines = ['event_1']
      end
      subject.publish(parent)
      subject.publish(subevent)

      feed = subject.timeline('with_subevent')
      feed['items'].first.subevents.should eq([subevent])
    end

  end

end

