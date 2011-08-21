require 'functional_helper'

describe "The Chronologic API" do

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

  context "GET /timeline/[timeline_key]" do

    it "does not return a next page key if there is no more data" do
      events = make_timeline # 10 events
      feed = connection.timeline("user_1_feed", :per_page => events.length)
      feed["next_page"].should be_nil
    end

    it "returns 404 if the timeline key isn't found"

    it "uses next_page to page through a timeline" do
      events = make_timeline # 10 events
      feed = connection.timeline("user_1_feed", :per_page => 5)
      feed = connection.timeline("user_1_feed", :per_page => 5, :page => feed["next_page"])
      feed["next_page"].should be_nil
    end

  end

  def make_timeline
    jp = {"name" => "Juan Pelota's"}
    connection.record("spot_1", jp)

    events = []
    %w{sco jc am pb mt rm ak ad rs bf}.each_with_index do |u, i|
      record = {"name" => u}
      key = "user_#{i}"
      connection.record(key, record)

      connection.subscribe("user_1_feed", "user_#{i}")

      event = simple_event
      event.key = "checkin_#{i}"
      event.objects["user"] = key
      event.timelines = [key, "spot_1"]

      events << event
      connection.publish(event)
    end

    return events
  end

end

