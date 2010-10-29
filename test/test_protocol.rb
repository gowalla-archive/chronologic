require "helper"

describe Chronologic::Protocol do

  before do
    @protocol = Chronologic::Protocol.new
    @protocol.schema = chronologic_schema
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
    key = "checkin_1111"
    timestamp = Time.now.utc
    data = {"type" => "checkin", "message" => "I'm here!"}
    objects = {"user" => "user_1", "spot" => "spot_1"}
    timelines = ["user_1"]

    @protocol.publish(key, timestamp, data, objects, timelines)
    @protocol.subscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal ["user_1_home"]
    @protocol.schema.timeline_events_for("user_1_home").must_include key
  end

  it "unsubscribes a subscriber key from a timeline key" do
    key = "checkin_1111"
    timestamp = Time.now.utc
    data = {"type" => "checkin", "message" => "I'm here!"}
    objects = {"user" => "user_1", "spot" => "spot_1"}
    timelines = ["user_1"]

    @protocol.publish(key, timestamp, data, objects, timelines)
    @protocol.subscribe("user_1_home", "user_1")
    @protocol.unsubscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal []
    @protocol.schema.timeline_events_for("user_1_home").must_equal []
  end

  it "publishes an event to one or more timeline keys" do
    key = "checkin_1111"
    timestamp = Time.now.utc
    data = {"type" => "checkin", "message" => "I'm here!"}
    objects = {"user" => "user_1", "spot" => "spot_1"}
    timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    event = @protocol.publish(key, timestamp, data, objects, timelines)

    event = @protocol.schema.event_for(key)
    event["timestamp"].must_equal({timestamp.iso8601 => ''})
    event["data"].must_equal data
    event["objects"].must_equal objects
    @protocol.schema.timeline_events_for("user_1_home").must_include key
    timelines.each do |t|
      @protocol.schema.timeline_events_for(t).must_include key
    end
  end

  it "unpublishes an event from one or more timeline keys" do
    skip("remove event and clean up timelines")
  end

  it "generates a feed for a timeline key" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("spot_1", jp)

    key = "checkin_1111"
    timestamp = Time.now.utc
    data = {"type" => "checkin", "message" => "I'm here!"}
    objects = {"user" => "user_1", "spot" => "spot_1"}
    timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    @protocol.publish(key, timestamp, data, objects, timelines)

    ["user_1", "spot_1", "user_1_home"].each do |t|
      feed = @protocol.feed(t)
      feed[0]["data"].must_equal data
      feed[0]["objects"]["user"].must_equal @protocol.schema.object_for("user_1")
      feed[0]["objects"]["spot"].must_equal @protocol.schema.object_for("spot_1")
    end
  end

  it "generates a feed for a timeline key, fetching nested timelines" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("user_2", sco)
    @protocol.record("spot_1", jp)

    key = "checkin_1111"
    timestamp = Time.now.utc
    data = {"type" => "checkin", "message" => "I'm here!"}
    objects = {"user" => "user_1", "spot" => "spot_1"}
    timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    event = @protocol.publish(key, timestamp, data, objects, timelines)

    key = "comment_1"
    timestamp = Time.now.utc
    data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1111"}
    objects = {"user" => "user_2"}
    timelines = ["checkin_1111"]
    @protocol.publish(key, timestamp, data, objects, timelines)

    @protocol.schema.timeline_events_for("checkin_1111").must_include key
    event = @protocol.feed("user_1_home", true).first["subevents"].first
    event["data"].must_equal data
    event["objects"]["user"].must_equal @protocol.schema.object_for("user_2")
  end

end

