require "helper"

describe Chronologic::Feed do

  before do
    @protocol = Chronologic::Protocol
  end

  it "fetches a timeline" do
    length = populate_timeline.length

    Chronologic::Feed.fetch("user_1_home").length.must_equal length
  end

  it "generates a feed for a timeline key" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    @protocol.record("user_1", akk)
    @protocol.record("spot_1", jp)

    event = simple_event

    @protocol.subscribe("user_1_home", "user_1")
    @protocol.publish(event)

    ["user_1", "spot_1", "user_1_home"].each do |t|
      feed = Chronologic::Feed.fetch(t)
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
    subevents = Chronologic::Feed.fetch("user_1_home", :fetch_subevents => true).first.subevents
    subevents.last.data.must_equal event.data
    subevents.first.objects["user"].must_equal @protocol.schema.object_for("user_2")
    subevents.last.objects["user"].must_equal @protocol.schema.object_for("user_1")
  end

  it "fetches a feed by page" do
    uuids = populate_timeline
    
    Chronologic::Feed.fetch("user_1_home", :page => uuids[1], :per_page => 5).length.must_equal(5)
  end

end
