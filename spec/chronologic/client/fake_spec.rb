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

    it "fetches a page of events on a timeline"

    it "fetches objects on events"

    it "fetches subevents on events"

  end

end
