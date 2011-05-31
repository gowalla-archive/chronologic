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

  it "doesn't fetch an empty array of objects" do
    raise_on_multiget

    @schema.object_for([]).must_equal Hash.new
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

  it 'creates a subscription with backlinks' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')

    @schema.followers_for('user_2').must_equal ['user_1']
  end

  it "fetches multiple subscriptions" do
    @schema.create_subscription("user_1_home", "user_2")
    @schema.create_subscription("user_2_home", "user_1")

    @schema.subscribers_for(["user_1", "user_2"]).must_include "user_1_home"
    @schema.subscribers_for(["user_1", "user_2"]).must_include "user_2_home"
  end

  it "doesn't fetch an empty array of subscriptions" do
    raise_on_multiget

    @schema.subscribers_for([]).must_equal Array.new
  end

  it "removes a subscription" do
    @schema.create_subscription("user_1", "user_2")
    @schema.remove_subscription("user_1", "user_2")

    @schema.subscribers_for("user_1").must_equal []
  end

  it 'checks whether a feed is connected to a timeline' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')
    @schema.create_subscription('user_3_home', 'user_2', 'user_3')

    @schema.followers_for('user_2').must_equal ['user_1', 'user_3']
  end

  it 'checks whether a feed is not connected to a timeline' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')

    @schema.followers_for('user_1').must_equal []
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

  it "does not fetch an empty array of events" do
    raise_on_multiget

    @schema.event_for([]).must_equal Hash.new
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

  it "creates timeline events without duplicates if timestamps match" do
    now = Time.now
    @schema.create_timeline_event("_global", @schema.new_guid(now), "gizmo_1111")
    @schema.create_timeline_event("_global", @schema.new_guid(now), "gizmo_1111")

    @schema.timeline_events_for("_global").length.must_equal 1
  end

  it "fetches timeline events with a count parameter" do
    uuids = 15.times.inject({}) { |result, i|
      uuid = @schema.new_guid
      ref = "gizmo_#{i}"

      @schema.create_timeline_event("_global", uuid, ref)
      result.update(uuid => ref)
    }.sort_by { |uuid, ref| uuid }

    events = @schema.timeline_for("_global", :per_page => 10)
    events.length.must_equal 10
    events.sort_by { |uuid, ref| uuid }.must_equal uuids.slice(5, 10)
  end

  it "fetches timeline events from a page offset" do
    uuids = 15.times.map { @schema.new_guid }.reverse
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

    @schema.timeline_for("_global", :per_page => 10, :page => uuids[11]).length.must_equal 10
    @schema.timeline_for("_global", :per_page => 10, :page => uuids[4]).length.must_equal 5, "doesn't truncate when length(count+offset) > length(results)"
  end

  it "does not fetch an empty array of timelines" do
    raise_on_multiget

    @schema.timeline_for([]).must_equal Hash.new
  end

  it "fetches an extra item when a page parameter is specified and truncates appropriately" do
    uuids = 15.times.inject({}) { |result, i|
      uuid = @schema.new_guid
      ref = "gizmo_#{i}"

      @schema.create_timeline_event("_global", uuid, ref)
      result.update(uuid => ref)
    }.sort_by { |uuid, ref| uuid }

    start = uuids[10][0]
    events = @schema.timeline_for(
      "_global", 
      :per_page => 5, 
      :page => start
    )
    events.length.must_equal 5
    events.sort_by { |uuid, ref| uuid }.must_equal uuids.slice(5, 5)
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

  it "generates a new guid" do
    @schema.new_guid.must_be_kind_of String
  end

  it "generates a guid given a timestamp" do
    t = Time.now
    @schema.new_guid(t).must_equal @schema.new_guid(t)
  end

  def simple_data
    {"checkin" => JSON.dump({"message" => "I'm here!"})}
  end

  def raise_on_multiget
    double = Object.new
    class <<double
      def multi_get(*args)
        raise "multi_get should not get called"
      end
    end

    Chronologic.connection = double
  end
end

