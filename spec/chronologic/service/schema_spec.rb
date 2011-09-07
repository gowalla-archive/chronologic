require 'spec_helper'

describe Chronologic::Service::Schema do 

  before do
    @schema = Chronologic::Service::Schema
  end

  it "creates an object" do
    attrs = {"name" => "akk"}
    @schema.create_object("user_1", attrs)

    @schema.object_for("user_1").should == attrs
  end

  it "fetches multiple objects" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    @schema.create_object("user_1", akk)
    @schema.create_object("user_2", sco)

    hsh = {"user_1" => akk, "user_2" => sco}
    @schema.object_for(["user_1", "user_2"]).should == hsh
  end

  it "doesn't fetch an empty array of objects" do
    raise_on_multiget

    @schema.object_for([]).should == Hash.new
  end

  it "removes an object" do
    @schema.create_object("user_1", {"name" => "akk"})
    @schema.remove_object("user_1")
    @schema.object_for("user_1").should == Hash.new
  end

  it "creates a subscription" do
    @schema.create_subscription("user_1_home", "user_2")

    @schema.subscribers_for("user_2").should == ["user_1_home"]
  end

  it 'creates a subscription with backlinks' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')

    @schema.followers_for('user_2').should == ['user_1']
  end

  it "fetches multiple subscriptions" do
    @schema.create_subscription("user_1_home", "user_2")
    @schema.create_subscription("user_2_home", "user_1")

    @schema.subscribers_for(["user_1", "user_2"]).should include("user_1_home")
    @schema.subscribers_for(["user_1", "user_2"]).should include("user_2_home")
  end

  it "doesn't fetch an empty array of subscriptions" do
    raise_on_multiget

    @schema.subscribers_for([]).should == Array.new
  end

  it "removes a subscription" do
    @schema.create_subscription("user_1", "user_2")
    @schema.remove_subscription("user_1", "user_2")

    @schema.subscribers_for("user_1").should == []
  end

  it 'checks whether a feed is connected to a timeline' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')
    @schema.create_subscription('user_3_home', 'user_2', 'user_3')

    @schema.followers_for('user_2').should == ['user_1', 'user_3']
  end

  it 'checks whether a feed is not connected to a timeline' do
    @schema.create_subscription('user_1_home', 'user_2', 'user_1')

    @schema.followers_for('user_1').should == []
  end

  it "checks the existence of an event" do
    @schema.create_event("checkin_1111", simple_data)
    @schema.event_exists?("checkin_1111").should be_true
  end

  it "creates an event" do
    data = simple_data
    @schema.create_event("checkin_1111", data)
    @schema.event_for("checkin_1111").should == data
  end

  it "fetches multiple events" do
    data = simple_data

    @schema.create_event("checkin_1111", data)
    @schema.create_event("checkin_1112", data)

    @schema.event_for(["checkin_1111", "checkin_1112"]).should == {"checkin_1111" => data, "checkin_1112" => data}
  end

  it "does not fetch an empty array of events" do
    raise_on_multiget

    @schema.event_for([]).should == Hash.new
  end

  it "removes an event" do
    @schema.create_event("checkin_1111", simple_data)
    @schema.remove_event("checkin_1111")
    @schema.event_for("checkin_1111").should == Hash.new
  end

  it "updates an event" do
    data = simple_data
    @schema.create_event("checkin_1111", data)

    data["hotness"] = "So new!"
    @schema.update_event("checkin_1111", data)

    @schema.event_for("checkin_1111").should eq(data)
  end

  it "creates a new timeline event" do
    key = "gizmo_1111"
    token = [Time.now.tv_sec, key].join('_')
    data = {"gizmo" => JSON.dump({"message" => "I'm here!"})}
    @schema.create_event(key, data)
    @schema.create_timeline_event("_global", token, key)

    @schema.timeline_for("_global").should ==({token => key})
    @schema.timeline_events_for("_global").values.should == [key]
  end

  it "creates timeline events without duplicates if timestamps match" do
    key = "gizmo_1111"
    token = [Time.now.tv_sec, key].join('_')
    @schema.create_timeline_event("_global", token, key)
    @schema.create_timeline_event("_global", token, key)

    @schema.timeline_events_for("_global").length.should == 1
  end

  it "fetches timeline events with a count parameter" do
    tokens = 15.times.inject({}) { |result, i|
      key = "gizmo_#{i}"
      token = [Time.now.tv_sec, key].join('_')

      @schema.create_timeline_event("_global", token, key)
      result.update(token => key)
    }.sort_by { |token, key| token }

    events = @schema.timeline_for("_global", :per_page => 10)
    events.length.should == 10
    events.sort_by { |token, key| token }.should == tokens.slice(5, 10)
  end

  it "fetches timeline events from a page offset" do
    pending('rewrite to work with real cassandra and mocked cassandra')
    uuids = 15.times.map { @schema.new_guid }.reverse
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      @schema.create_timeline_event("_global", uuid, ref)
    end

    offset = uuids[10]
    @schema.timeline_for("_global", :page => offset).length.should == 5
  end

  it "fetches timeline events with a count and offset parameter" do
    pending('rewrite to work with real cassandra and mocked cassandra')
    uuids = 15.times.map { @schema.new_guid }
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      @schema.create_timeline_event("_global", uuid, ref)
    end

    @schema.timeline_for("_global", :per_page => 10, :page => uuids[11]).length.should == 10
    @schema.timeline_for("_global", :per_page => 10, :page => uuids[4]).length.should == 5#, "doesn't truncate when length(count+offset) > length(results)"
  end

  it "does not fetch an empty array of timelines" do
    raise_on_multiget

    @schema.timeline_for([]).should == Hash.new
  end

  it "fetches an extra item when a page parameter is specified and truncates appropriately" do
    pending('rewrite to work with real cassandra and mocked cassandra')
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
    events.length.should == 5
    events.sort_by { |uuid, ref| uuid }.should == uuids.slice(5, 5)
  end

  it "removes a timeline event" do
    data = simple_data
    key = "gizmo_1111"
    token = [Time.now.tv_sec, key].join("_")

    @schema.create_event("gizmo_1111", data)
    @schema.create_timeline_event("_global", token, key)
    @schema.remove_timeline_event("_global", token)

    @schema.timeline_events_for("_global").values.should == []
  end

  it "counts items in a timeline" do
    pending("Cheating on counts for a while")
    10.times { |i| @schema.create_timeline_event("_global", i.to_s, "junk") }
    @schema.timeline_count("_global").should == 10
  end

  it "fetches events for one or more timelines" do
    protocol = Chronologic::Service::Protocol # HAX

    events = [simple_event]
    events << simple_event.tap do |e|
      e.key = "checkin_2"
      e.data['message'] = "I'm over there!"
    end
    events << simple_event.tap do |e|
      e.key = "checkin_3"
      e.data['message'] = "I'm way over there!"
    end
    events << simple_event.tap do |e|
      e.key = "checkin_4"
      e.data['message'] = "I'm over here!"
      e.timelines = ["user_2"]
    end
    events << simple_event.tap do |e|
      e.key = "checkin_5"
      e.data['message'] = "I'm nowhere!"
      e.timelines = ["user_2"]
    end
    events.each { |e| protocol.publish(e) }

    events = subject.fetch_timelines(["user_1", "user_2"])

    events.length.should == 5
    events.each { |e| e.should be_instance_of(Chronologic::Event) }
  end

  it "fetches objects associated with an event" do
    protocol = Chronologic::Service::Protocol # HAX

    protocol.record("spot_1", {"name" => "Juan Pelota's"})
    protocol.record("user_1", {"name" => "akk"})
    protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    populated_event = subject.fetch_objects([event]).first

    populated_event.objects["test"].length.should == 2
    populated_event.objects["user"].should be_kind_of(Hash)
    populated_event.objects["spot"].should be_kind_of(Hash)
  end

  describe "feed reification" do

    it "constructs a feed from multiple events" do
      events = 5.times.map { simple_event }

      timeline = subject.reify_timeline(events)

      timeline.length.should == 5
    end

    it "constructs a feed from events with subevents" do
      events = [simple_event, nested_event]

      timeline = subject.reify_timeline(events)

      timeline.length.should == 1
      timeline.first.subevents.should == [events.last]
    end

    it "constructs a feed from events with sub-subevents" do
      events = [simple_event, nested_event]

      events << simple_event.tap do |e|
        e.key = "checkin_2"
        e.data['message'] = "I'm over there"
      end

      events << simple_event.tap { |e| e.key = "grouping_1" }
      events << simple_event.tap do |e|
        e.key = "checkin_3"
        e.parent = "grouping_1"
        e.timelines << "grouping_1"
      end
      events << simple_event.tap do |e|
        e.key = "comment_2"
        e.parent = "checkin_3"
        e.timelines << "checkin_3"
      end

      timeline = subject.reify_timeline(events)

      timeline.length.should == 3
      timeline[0].subevents.length.should == 1
      timeline[1].subevents.length.should == 0
      timeline[2].subevents.length.should == 1
      timeline[2].subevents[0].subevents.length.should == 1
    end

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

