require "helper"

describe Chronologic::Schema do 

  before do
    @schema = chronologic_schema
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

    hsh = {"user_1" => akk, "user_2" => sco}
    @schema.object_for(["user_1", "user_2"]).must_equal hsh
  end

  it "removes an object" do
    @schema.create_object("user_1", {"name" => "akk"})
    @schema.remove_object("user_1")
    @schema.object_for("user_1").must_equal Hash.new
  end

  it "creates a subscription" do
    @schema.create_subscription("user_1_home", "user_2")

    @schema.subscribers_for("user_2").must_equal ["user_1_home"]
  end

  it "fetches multiple subscriptions" do
    @schema.create_subscription("user_1_home", "user_2")
    @schema.create_subscription("user_2_home", "user_1")

    @schema.subscribers_for(["user_1", "user_2"]).must_include "user_1_home"
    @schema.subscribers_for(["user_1", "user_2"]).must_include "user_2_home"
  end

  it "removes a subscription" do
    @schema.create_subscription("user_1", "user_2")
    @schema.remove_subscription("user_1", "user_2")

    @schema.subscribers_for("user_1").must_equal []
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

    @schema.event_for(["checkin_1111", "checkin_1112"]).must_equal("checkin_1111" => data, "checkin_1112" => data)
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
    uuid = @schema.new_guid
    data = {"gizmo" => {"message" => "I'm here!"}}
    @schema.create_event("gizmo_1111", data)
    @schema.create_timeline_event("_global", uuid, "gizmo_1111")

    @schema.timeline_for("_global").must_equal({uuid => "gizmo_1111"})
    @schema.timeline_events_for("_global").must_equal ["gizmo_1111"]
  end

  it "removes a timeline event" do
    data = {"gizmo" => {"message" => "I'm here!"}}
    uuid = @schema.create_event("gizmo_1111", data)
    timeline_guid = @schema.new_guid
    @schema.create_timeline_event("_global", timeline_guid, "gizmo_1111")
    @schema.remove_timeline_event("_global", uuid)
    @schema.timeline_events_for("_global").must_equal []
  end

end

