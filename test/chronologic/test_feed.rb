require "helper"

describe Chronologic::Feed do

  before do
    @protocol = Chronologic::Protocol
  end

  it "fetches a timeline" do
    length = populate_timeline.length

    Chronologic::Feed.create("user_1_home").items.length.must_equal length
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
      feed = Chronologic::Feed.create(t).items
      feed[0].data.must_equal event.data
      feed[0].objects["user"].must_equal @protocol.schema.object_for("user_1")
      feed[0].objects["spot"].must_equal @protocol.schema.object_for("spot_1")
    end
  end

  it "generates a feed and properly handles empty subevents" do
    event = simple_event
    @protocol.publish(event)

    feed = Chronologic::Feed.create(
      event.timelines.first, 
      :fetch_subevents => true
    )
    feed.items.first.subevents.must_equal []
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

    @protocol.schema.timeline_events_for("checkin_1111").values.must_include event.key
    subevents = Chronologic::Feed.create("user_1_home", :fetch_subevents => true).items.first.subevents
    subevents.last.data.must_equal event.data
    subevents.first.objects["user"].must_equal @protocol.schema.object_for("user_2")
    subevents.last.objects["user"].must_equal @protocol.schema.object_for("user_1")
  end

  it "fetches a feed by page" do
    uuids = populate_timeline
    
    Chronologic::Feed.create(
      "user_1_home", 
      :page => uuids[1], 
      :per_page => 5
    ).items.length.must_equal(5)
  end

  # AKK: it would be great if we didn't have to call feed.items to load
  # the paging bits

  it "tracks the event key for the next page" do
    uuids = populate_timeline
    feed = Chronologic::Feed.new("user_1_home")
    feed.items

    feed.next_page.must_equal uuids.first
  end

  it "stores the item count for the feed" do
    uuids = populate_timeline
    feed = Chronologic::Feed.new("user_1_home")
    feed.items

    feed.count.must_equal uuids.length
  end

  it "fetches multiple objects per type" do
    @protocol.record("user_1", {"name" => "akk"})
    @protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    @protocol.publish(event)
    feed = Chronologic::Feed.create(event.timelines.first)
    feed.items.first.objects["test"].length.must_equal 2
  end

  it "fetches two levels of subevents" do
    grouping = simple_event
    grouping.key = "grouping_1"
    grouping['data'] = {"grouping" => "flight"}
    grouping.timelines = ["subsubevent_test"]

    event = simple_event
    event['data']['parent'] = grouping.key
    event.timelines = [grouping.key]

    subevent = simple_event
    subevent.key = "comment_1"
    subevent['data']['type'] = "comment"
    subevent['data']['parent'] = event.key
    subevent['data']['message'] = "Great!"
    subevent.timelines = [event.key]

    @protocol.publish(grouping)
    @protocol.publish(event)
    @protocol.publish(subevent)

    feed = Chronologic::Feed.new("subsubevent_test", 20, nil, true)
    feed.items.first.
      subevents.first.
      subevents.first.must_equal subevent
  end

end
