require "helper"

describe Chronologic::Schema do 

  before do
    @schema = Chronologic::Schema
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
    data = simple_data
    @schema.create_event("checkin_1111", data)
    @schema.event_for("checkin_1111").must_equal data
  end

  it "fetches multiple events" do
    data = simple_data

    @schema.create_event("checkin_1111", data)
    @schema.create_event("checkin_1112", data)

    @schema.event_for(["checkin_1111", "checkin_1112"]).must_equal("checkin_1111" => data, "checkin_1112" => data)
  end

  it "removes an event" do
    @schema.create_event("checkin_1111", simple_data)
    @schema.remove_event("checkin_1111")
    @schema.event_for("checkin_1111").must_equal Hash.new
  end

  it "creates a new timeline event" do
    uuid = @schema.new_guid
    data = {"gizmo" => JSON.dump({"message" => "I'm here!"})}
    @schema.create_event("gizmo_1111", data)
    @schema.create_timeline_event("_global", uuid, "gizmo_1111")

    @schema.timeline_for("_global").must_equal({uuid => "gizmo_1111"})
    @schema.timeline_events_for("_global").values.must_equal ["gizmo_1111"]
  end

  it "fetches timeline events with a count parameter" do
    15.times do |i|
      uuid = @schema.new_guid
      ref = "gizmo_#{i}"

      @schema.create_timeline_event("_global", uuid, ref)
    end
    
    @schema.timeline_for("_global", :per_page => 10).length.must_equal 10
  end

  it "fetches timeline events from a page offset" do
    uuids = 15.times.map { @schema.new_guid }
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      @schema.create_timeline_event("_global", uuid, ref)
    end

    offset = uuids[10]
    @schema.timeline_for("_global", :page => offset).length.must_equal 5
  end

  it "fetches timeline events with a count and offset parameter" do
    uuids = 15.times.map { @schema.new_guid }
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      @schema.create_timeline_event("_global", uuid, ref)
    end

    offset = uuids[10]
    @schema.timeline_for("_global", :per_page => 10, :page => offset).length.must_equal 5
  end

  it "removes a timeline event" do
    data = simple_data
    uuid = @schema.create_event("gizmo_1111", data)
    timeline_guid = @schema.new_guid
    @schema.create_timeline_event("_global", timeline_guid, "gizmo_1111")

    @schema.remove_timeline_event("_global", timeline_guid)
    @schema.timeline_events_for("_global").values.must_equal []
  end

  it "counts items in a timeline" do
    10.times { @schema.create_timeline_event("_global", @schema.new_guid, "junk") }
    @schema.timeline_count("_global").must_equal 10
  end

  def simple_data
    {"checkin" => JSON.dump({"message" => "I'm here!"})}
  end
end

