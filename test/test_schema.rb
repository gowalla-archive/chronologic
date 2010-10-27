require "rubygems"
require "minitest/spec"
MiniTest::Unit.autorun

require "chronologic"

describe Chronologic::Schema do 

  before do
    @schema = Chronologic::Schema.new
    @schema.connection = Cassandra.new("Chronologic")
    @schema.connection.clear_keyspace!
  end

  it "creates an object" do
    attrs = {"name" => "akk"}
    @schema.create_object("user_1", attrs)

    @schema.object_for("user_1").must_equal attrs
  end

  it "fetches multiple objects" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    @schema.create_object("user_1", akk)
    @schema.create_object("user_2", sco)

    @schema.object_for(["user_1", "user_2"]).must_equal [akk, sco]
  end

  it "removes an object" do
    @schema.create_object("user_1", {"name" => "akk"})
    @schema.remove_object("user_1")
    @schema.object_for("user_1").must_equal Hash.new
  end

  it "creates a subscription" do
    @schema.create_object("user_1", {"name" => "akk"})
    @schema.create_object("user_2", {"name" => "sco"})
    @schema.create_subscription("user_1", "user_2")

    @schema.subscribers_for("user_1").must_equal ["user_2"]
    @schema.subscriptions_for("user_2").must_equal ["user_1"]
  end

  it "removes a subscription" do
    skip
  end

  it "creates an event" do
    data = {"checkin" => {"message" => "I'm here!"}}

    @schema.create_event("checkin_1111", data)
    @schema.event_for("checkin_1111").must_equal data
  end

  it "fetches multiple events" do
    data = {"checkin" => {"message" => "I'm here!"}}

    @schema.create_event("checkin_1111", data)
    @schema.create_event("checkin_1112", data)

    @schema.event_for(["checkin_1111", "checkin_1112"]).must_equal [data, data]
  end

  it "removes an event" do
    @schema.create_event(
      "checkin_1111", 
      {"checkin" => {"message" => "I'm here!"}}
    )
    @schema.remove_event("checkin_1111")
    @schema.event_for("checkin_1111").must_equal Hash.new
  end

  it "creates a new timeline event" do
    data = {"gizmo" => {"message" => "I'm here!"}}
    @schema.create_event("gizmo_1111", data)
    @schema.create_timeline_event("_global", "gizmo_1111")

    @schema.timeline_events_for("_global").must_equal ["gizmo_1111"]
  end

  it "removes a timeline event" do
    data = {"gizmo" => {"message" => "I'm here!"}}
    uuid = @schema.create_event("gizmo_1111", data)
    @schema.create_timeline_event("_global", "gizmo_1111")
    @schema.remove_timeline_event("_global", uuid)
    @schema.timeline_events_for("_global").must_equal []
  end

end

