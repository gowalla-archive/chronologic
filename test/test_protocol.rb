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
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1"]

    @protocol.publish(event)
    @protocol.subscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal ["user_1_home"]
    @protocol.schema.timeline_events_for("user_1_home").must_include event.key
  end

  it "unsubscribes a subscriber key from a timeline key" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1"]

    @protocol.publish(event)
    @protocol.subscribe("user_1_home", "user_1")
    @protocol.unsubscribe("user_1_home", "user_1")

    @protocol.schema.subscribers_for("user_1").must_equal []
    @protocol.schema.timeline_events_for("user_1_home").must_equal []
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

    fetched = @protocol.schema.event_for(event.key)
    fetched["timestamp"].must_equal({event.timestamp.iso8601 => ''})
    fetched["data"].must_equal event.data
    fetched["objects"].must_equal event.objects
    @protocol.schema.timeline_events_for("user_1_home").must_include event.key
    event.timelines.each do |t|
      @protocol.schema.timeline_events_for(t).must_include event.key
    end
  end

  it "unpublishes an event from one or more timeline keys" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    uuid = @protocol.publish(event)
    @protocol.unpublish(event, uuid)

    @protocol.schema.event_for(event.key).must_equal Hash.new
    @protocol.schema.timeline_events_for("user_1_home").wont_include event.key
    event.timelines.each do |t|
      @protocol.schema.timeline_events_for(t).wont_include event.key
    end
  end

  it "generates a feed for a timeline key" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("spot_1", jp)

    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    @protocol.publish(event)

    ["user_1", "spot_1", "user_1_home"].each do |t|
      feed = @protocol.feed(t)
      feed[0].data.must_equal event.data
      feed[0].objects["user"].must_equal @protocol.schema.object_for("user_1")
      feed[0].objects["spot"].must_equal @protocol.schema.object_for("spot_1")
    end
  end

  it "generates a feed for a timeline key, fetching nested timelines" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("user_2", sco)
    @protocol.record("spot_1", jp)

    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @protocol.subscribe("user_1_home", "user_1")
    event = @protocol.publish(event)

    event = Chronologic::Event.new
    event.key = "comment_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_2"}
    event.timelines = ["checkin_1111"]
    @protocol.publish(event)

    event = Chronologic::Event.new
    event.key = "comment_2222"
    event.timestamp = Time.now.utc
    event.data = {"type" => "comment", "message" => "Great!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_1"}
    event.timelines = ["checkin_1111"]
    @protocol.publish(event)

    @protocol.schema.timeline_events_for("checkin_1111").must_include event.key
    subevents = @protocol.feed("user_1_home", true).first.subevents
    subevents.last.data.must_equal event.data
    subevents.first.objects["user"].must_equal @protocol.schema.object_for("user_2")
    subevents.last.objects["user"].must_equal @protocol.schema.object_for("user_1")
  end

end
