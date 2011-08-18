require 'functional_helper'

describe "The Chronologic API" do

  let(:connection) { Chronologic::Client::Connection.instance = Chronologic::Client::Connection.new('http://localhost:9292') }
  before do
    c = Cassandra.new("Chronologic")
    [:Object, :Subscription, :Timeline, :Event].each do |cf|
      c.truncate!(cf)
    end
  end

  context "GET /event/[event_key]" do

    it "returns an event" do
      event = simple_event
      url = connection.publish(simple_event)

      connection.fetch(url).key.should eq(event.key)
    end

    it "returns 404 if the event isn't present" do
      expect { connection.fetch('/event/thingy_123') }.to raise_exception(Chronologic::NotFound)
    end

  end

  context "PUT /event/[event_key]" do

    it "updates an existing event" do
      event = simple_event
      url = connection.publish(simple_event)

      event.data["brand-new"] = "totally fresh!"
      connection.update(event)

      connection.fetch(url).data["brand-new"].should eq("totally fresh!")
    end

    it "reprocesses timelines if update_timeline is set" do
      event = simple_event
      url = connection.publish(simple_event)

      event.timelines << 'another_timeline'
      connection.update(event, true)

      connection.timeline('another_timeline')["items"].first.key.should eq(event.key)
    end

  end

end
