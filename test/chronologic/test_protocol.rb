require "helper"

describe Chronologic::Protocol do

  before do
    @protocol = Chronologic::Protocol
  end

  it "records an entity" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("spot_1", jp)

    hsh = {"user_1" => akk, "spot_1" => jp}
    @protocol.schema.object_for(["user_1", "spot_1"]).must_equal hsh
  end

  it "unrecords an entity" do
    @protocol.record("user_1", {"name" => "akk"})
    @protocol.unrecord("user_1")

    @protocol.schema.object_for("user_1").must_equal Hash.new
  end

  it "subscribes a subscriber key to a timeline key and populates a timeline" do
    event = simple_event

    @protocol.publish(event)
    @protocol.subscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal ["user_1_home"]
    @protocol.schema.timeline_events_for("user_1_home").values.must_include event.key
  end

  it "unsubscribes a subscriber key from a timeline key" do
    event = simple_event

    @protocol.publish(event)
    @protocol.subscribe("user_1_home", "user_1")
    @protocol.unsubscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal []
    @protocol.schema.timeline_events_for("user_1_home").values.must_equal []
  end

  it "publishes an event to one or more timeline keys" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    @protocol.publish(event)

    fetched = Chronologic::Event.load_from_columns(@protocol.schema.event_for(event.key))
    fetched["timestamp"].iso8601.must_equal event.timestamp.iso8601
    fetched["data"].must_equal event.data
    fetched["objects"].must_equal event.objects
    @protocol.schema.timeline_events_for("user_1_home").values.must_include event.key
    event.timelines.each do |t|
      @protocol.schema.timeline_events_for(t).values.must_include event.key
    end
  end

  it "unpublishes an event from one or more timeline keys" do
    event = simple_event

    @protocol.subscribe("user_1_home", "user_1")
    uuid = @protocol.publish(event)
    @protocol.unpublish(event, uuid)

    @protocol.schema.event_for(event.key).must_equal Hash.new
    @protocol.schema.timeline_events_for("user_1_home").wont_include event.key
    event.timelines.each do |t|
      @protocol.schema.timeline_events_for(t).wont_include event.key
    end
  end

  # AKK: no test for Protocol.feed since it delegates everything to Feed

  it "counts item in a feed" do
    populate_timeline
    @protocol.feed_count("user_1_home").must_equal 10
  end

end

