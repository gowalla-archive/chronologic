require 'spec_helper'

describe Chronologic::Client::Fake do

  describe "#record" do
    it "stores an object" do
      subject.record("thing_1", {"thingy" => "thingoid"})
      subject.objects.should include("thing_1" => {"thingy" => "thingoid"})
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

    it "checks if a subscriber is strongly connected to a consumer" do
      subject.subscribe("user_akk", "user_mt_feed", "user_mt")
      subject.should be_connected("user_akk", "user_mt")
    end

  end

  describe "#publish" do

    it "creates a new event" do
      event = stub('event', :key => 'event_1', :timelines => [])
      subject.publish(event)
      subject.events.values.should include(event)
    end

    it "writes the event to each specified timeline" do
      event = stub(
        'event',
        :key => 'event_1',
        :timelines => ['foo'],
        :timestamp => Time.now
      )
      subject.publish(event)
      subject.timelines['foo'].values.should include('event_1')
    end

    it "writes the event to subscribed timelines" do
      subject.subscribe('user_1', 'user_2')
      event = double(
        :event,
        :key => 'event_1',
        :timelines => ['user_1'],
        :timestamp => 1
      )
      subject.publish(event)
      subject.timelines['user_2'].values.should include(event.key)
    end

    it "returns a CL key instead of a URL" do
      event = stub('event', :key => 'event_1', :timelines => [])
      subject.publish(event).should eq('event_1')
    end

  end

  describe "#fetch" do

    it "retrieves an event" do
      event = double(
        'event',
        :key => 'event_1',
        :timelines => []
      ).as_null_object
      subject.publish(event)
      subject.fetch(event.key).should eq(event)
    end

    it "copies retrieved events" do
      event = double(:event, :key => 'event_1').as_null_object
      subject.publish(event)
      subject.fetch(event.key).should_not eql(event)
    end

    it "populates objects on fetched events" do
      object = double
      subject.record('object_1', object)

      event = Chronologic::Event.new(
        :key => 'event_1',
        :objects => {'objects' => ['object_1']}
      )
      subject.publish(event)

      subject.fetch(event.key).objects['objects']['object_1'].should eq(object)
    end

    it "fetches subevents on fetched events" do
      event = Chronologic::Event.new(
        :key => 'event_1'
      )
      subject.publish(event)

      subevent = Chronologic::Event.new(
        :key => 'subevent_1',
        :timelines => [event.key]
      )
      subject.publish(subevent)

      subject.fetch(event.key).subevents.should include(subevent)
    end

    it "populates objects on fetched subevents" do
      object = double
      subject.record('object_1', object)

      event = Chronologic::Event.new(
        :key => 'event_1'
      )
      subject.publish(event)

      subevent = Chronologic::Event.new(
        :key => 'subevent_1',
        :timelines => [event.key],
        :objects => {'objects' => ['object_1']}
      )
      subject.publish(subevent)

      fetched = subject.fetch(event.key).subevents.first
      fetched.objects['objects'].should include('object_1' => object)
    end

  end

  describe "#update" do

    it "rewrites an existing event" do
      event = double('event', :key => 'event_1').as_null_object
      subject.publish(event)
      updated = double(
        'event',
        :key => 'event_1',
        :timelines => []
      ).as_null_object
      subject.update(updated)
      subject.fetch(event.key).should eq(updated)
    end

  end

  describe "#timeline" do

    let(:events) do
      10.times.map do |i|
        event = double(
          :event,
          :key => "event_#{i}",
          :objects => {},
          :timelines => ['home'],
          :timestamp => i
        ).as_null_object
      end
    end
    before { events.each { |e| subject.publish(e) } }

    it "fetches a page of events on a timeline" do
      feed = subject.timeline('home')

      feed['count'].should eq(10)
      feed['items'].should eq(events)
    end

    it "fetches the specified number of events" do
      feed = subject.timeline('home', 'per_page' => 5)

      feed['count'].should eq(10)
      feed['items'].length.should eq(5)
    end

    it "fetches from a page offset" do
      token = subject.timeline('home', 'per_page' => 5)['next_page']
      feed = subject.timeline('home', 'per_page' => 5, 'page' => token)

      feed['count'].should eq(10)
      feed['items'].length.should eq(5)
      feed['items'].should eq(events.last(5))
    end

    it "fetches objects on events" do
      object = double(:object).as_null_object
      subject.record('object_1', object)

      with_object = Chronologic::Event.new(
        :key => 'event_100',
        :timelines => ['with_object'],
        :objects => {"object" => ['object_1']},
        :timestamp => 1
      )
      subject.publish(with_object)

      feed = subject.timeline('with_object')
      feed['items'].first['objects']["object"].should eq({"object_1" => object})
    end

    it "fetches subevents on events" do
      parent = Chronologic::Event.new(
        :key => 'event_1',
        :timelines => ['with_subevent'],
        :objects => {},
        :timestamp => 1
      )
      subevent = Chronologic::Event.new(
        :key => 'event_2',
        :timelines => ['event_1'],
        :objects => {},
        :timestamp => 2
      )

      subject.publish(parent)
      subject.publish(subevent)

      feed = subject.timeline('with_subevent')
      feed['items'].first['subevents'].should eq([subevent])
    end

  end

end
