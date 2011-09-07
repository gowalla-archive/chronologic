require 'spec_helper'

describe Chronologic::Service::Feed do

  let(:protocol) { Chronologic::Service::Protocol }
  subject { Chronologic::Service::Feed }

  it "fetches a timeline" do
    length = populate_timeline.length

    subject.create("user_1_home").items.length.should == length
  end

  it "generates a feed for a timeline key" do
    akk = {"name" => "akk"}
    jp = {"name" => "Juan Pelota's"}
    protocol.record("user_1", akk)
    protocol.record("spot_1", jp)

    event = simple_event

    protocol.subscribe("user_1_home", "user_1")
    protocol.publish(event)

    ["user_1", "spot_1", "user_1_home"].each do |t|
      feed = subject.create(t).items
      feed[0].data.should == event.data
      feed[0].objects["user"].should == protocol.schema.object_for("user_1")
      feed[0].objects["spot"].should == protocol.schema.object_for("spot_1")
    end
  end

  it "generates a feed and properly handles empty subevents" do
    event = simple_event
    protocol.publish(event)

    feed = subject.create(
      event.timelines.first,
      :fetch_subevents => true
    )
    feed.items.first.subevents.should == []
  end

  it "generates a feed for a timeline key, fetching nested timelines" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    jp = {"name" => "Juan Pelota's"}
    protocol.record("user_1", akk)
    protocol.record("user_2", sco)
    protocol.record("spot_1", jp)

    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    protocol.subscribe("user_1_home", "user_1")
    event = protocol.publish(event)

    event = Chronologic::Event.new
    event.key = "comment_1111"
    event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_2"}
    event.timelines = ["checkin_1111"]
    protocol.publish(event)

    event = Chronologic::Event.new
    event.key = "comment_2222"
    event.data = {"type" => "comment", "message" => "Great!", "parent" => "checkin_1111"}
    event.objects = {"user" => "user_1"}
    event.timelines = ["checkin_1111"]
    protocol.publish(event)

    protocol.schema.timeline_events_for("checkin_1111").values.should include(event.key)
    subevents = subject.create("user_1_home", :fetch_subevents => true).items.first.subevents
    subevents.last.data.should == event.data
    subevents.first.objects["user"].should == protocol.schema.object_for("user_2")
    subevents.last.objects["user"].should == protocol.schema.object_for("user_1")
  end

  it "fetches a feed by page" do
    populate_timeline
    page = subject.create("user_1_home", :per_page => 5).next_page

    subject.create(
      "user_1_home",
      :page => page,
      :per_page => 5
    ).items.length.should ==(5)
  end

  # AKK: it would be great if we didn't have to call feed.items to load
  # the paging bits

  it "tracks the event key for the next page" do
    populate_timeline
    feed = subject.new("user_1_home", 1)
    feed.items

    feed.next_page.should_not be_nil
  end

  it "doesn't set the next page if there is no next page" do
    events = populate_timeline
    feed = subject.new("user_1_home", events.length)
    feed.items

    feed.next_page.should be_nil
  end

  it "stores the item count for the feed" do
    pending("Cheating on counts for a while")
    events = populate_timeline
    feed = subject.new("user_1_home")
    feed.items

    feed.count.should == events.length
  end

  it "fetches multiple objects per type" do
    protocol.record("user_1", {"name" => "akk"})
    protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    protocol.publish(event)
    feed = subject.create(event.timelines.first)
    feed.items.first.objects["test"].length.should == 2
  end

  it "fetches two levels of subevents" do
    grouping = simple_event
    grouping.key = "grouping_1"
    grouping['data'] = {"grouping" => "flight"}
    grouping.timelines = ["subsubevent_test"]

    event = simple_event
    event.parent = grouping.key
    event.timelines = [grouping.key]

    subevent = simple_event
    subevent.key = "comment_1"
    subevent.parent = event.key
    subevent['data']['type'] = "comment"
    subevent['data']['message'] = "Great!"
    subevent.timelines = [event.key]

    protocol.publish(grouping)
    protocol.publish(event)
    protocol.publish(subevent)

    feed = subject.new("subsubevent_test", 20, nil, true)
    feed.items.first.
      subevents.first.
      subevents.first.key.should == subevent.key
  end

end
