require 'spec_helper'

describe Chronologic::Service::ObjectlessFeed do

  let(:protocol) { Chronologic::Service::Protocol }
  subject { Chronologic::Service::ObjectlessFeed }

  it_behaves_like "a feed strategy"

  # AKK: reduce duplication of code in this examples
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
    end
  end

  # AKK: reduce duplication of code in this examples
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
  end

end
