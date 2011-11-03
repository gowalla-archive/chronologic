require 'chronologic'
require 'webmock/rspec'
require 'cassandra/0.7'
require 'cassandra/mock'
require 'helpers'

MultiJson.engine = :yajl

RSpec.configure do |config|
  config.include(ChronologicHelpers)
  config.include(WebMock::API)

  config.before do
    if ENV['CASSANDRA']
      Chronologic::Service::Schema.write_opts = {
        :consistency => Cassandra::Consistency::ONE
      }
      Chronologic.connection = Cassandra.new(
        'ChronologicTest',
        ['127.0.0.1:9160'],
        :connection_timeout => 3,
        :retries => 2,
        :timeout => 3
      )
      clean_up_keyspace!(Chronologic.connection)
    else
      schema = {
        'ChronologicTest' => {
          'Object' => {},
          'Subscription' => {},
          'Event' => {},
          'Timeline' => {}
        }
      }
      Chronologic.connection = Cassandra::Mock.new('ChronologicTest', schema)
    end
  end

  config.before do
    WebMock.disable_net_connect!
    WebMock.reset!
  end

end

shared_examples "a feed strategy" do

  it "fetches a timeline" do
    length = populate_timeline.length

    subject.create("user_1_home").items.length.should == length
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
    pending("Cheating on sub-subevents for now")
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

shared_examples_for "a CL event" do

  let(:nested_event) do
    described_class.from_attributes(
      :key => "comment_1",
      :data => {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1"},
      :objects => {"user" => "user_2"},
      :timelines => ["checkin_1"]
    )
  end

  it "knows whether it is a subevent" do
    nested_event.subevent?.should == true
  end

  it "knows its parent event" do
    nested_event.parent.should == "checkin_1"
  end

  it "sets its parent event" do
    event = nested_event
    event.parent = "highlight_1"
    event.parent.should == "highlight_1"
  end

  it "returns children as CL::Event objects" do
    subevent = {
      "key" => "bar_1",
      "data" => {"bar" => "herp"}
    }

    event = described_class.from_attributes(
      :key => "foo_1", 
      :data => {"foo" => "derp"}, 
      :subevents => [subevent]
    )
    event.children.should eq([described_class.from_attributes(subevent)])
  end

  it "flags an empty event" do
    subject.data = {}
    subject.should be_empty
  end

end

shared_examples_for "a CL schema" do

  let(:protocol) { Chronologic::Service::Protocol }

  it "creates an object" do
    attrs = {"name" => "akk"}
    subject.create_object("user_1", attrs)

    subject.object_for("user_1").should == attrs
  end

  it "fetches multiple objects" do
    akk = {"name" => "akk"}
    sco = {"name" => "sco"}
    subject.create_object("user_1", akk)
    subject.create_object("user_2", sco)

    hsh = {"user_1" => akk, "user_2" => sco}
    subject.object_for(["user_1", "user_2"]).should == hsh
  end

  it "doesn't fetch an empty array of objects" do
    reject_multiget

    subject.object_for([]).should == Hash.new
  end

  it "removes an object" do
    subject.create_object("user_1", {"name" => "akk"})
    subject.remove_object("user_1")
    subject.object_for("user_1").should == Hash.new
  end

  it "creates a subscription" do
    subject.create_subscription("user_1_home", "user_2")

    subject.subscribers_for("user_2").should == ["user_1_home"]
  end

  it 'creates a subscription with backlinks' do
    subject.create_subscription('user_1_home', 'user_2', 'user_1')

    subject.followers_for('user_2').should == ['user_1']
  end

  it "fetches multiple subscriptions" do
    subject.create_subscription("user_1_home", "user_2")
    subject.create_subscription("user_2_home", "user_1")

    subject.subscribers_for(["user_1", "user_2"]).should include("user_1_home")
    subject.subscribers_for(["user_1", "user_2"]).should include("user_2_home")
  end

  it "doesn't fetch an empty array of subscriptions" do
    reject_multiget

    subject.subscribers_for([]).should == Array.new
  end

  it "removes a subscription" do
    subject.create_subscription("user_1", "user_2")
    subject.remove_subscription("user_1", "user_2")

    subject.subscribers_for("user_1").should == []
  end

  it 'checks whether a feed is connected to a timeline' do
    subject.create_subscription('user_1_home', 'user_2', 'user_1')
    subject.create_subscription('user_3_home', 'user_2', 'user_3')

    subject.followers_for('user_2').should == ['user_1', 'user_3']
  end

  it 'checks whether a feed is not connected to a timeline' do
    subject.create_subscription('user_1_home', 'user_2', 'user_1')

    subject.followers_for('user_1').should == []
  end

  it "checks the existence of an event" do
    subject.create_event("checkin_1111", simple_data)
    subject.event_exists?("checkin_1111").should be_true
  end

  it "creates an event" do
    data = simple_data
    subject.create_event("checkin_1111", data)
    subject.event_for("checkin_1111").should == data
  end

  it "fetches multiple events" do
    data = simple_data

    subject.create_event("checkin_1111", data)
    subject.create_event("checkin_1112", data)

    subject.event_for(["checkin_1111", "checkin_1112"]).should == {"checkin_1111" => data, "checkin_1112" => data}
  end

  it "does not fetch an empty array of events" do
    reject_multiget

    subject.event_for([]).should == Hash.new
  end

  it "iterates over events" do
    keys = ["checkin_1111", "checkin_2222", "checkin_3333"]
    keys.each { |k| subject.create_event(k, simple_data) }

    event_keys = []
    subject.each_event do |key, event|
      event_keys << key
      event.should eq(simple_data)
    end

    event_keys.should eq(keys)
  end

  it "iterates over events, starting from a key" do
    keys = ["checkin_1111", "checkin_2222", "checkin_3333"]
    keys.each { |k| subject.create_event(k, simple_data) }

    event_keys = []
    subject.each_event('checkin_2222') do |key, event|
      event_keys << key
      event.should eq(simple_data)
    end

    event_keys.should have(2).items
  end

  it "removes an event" do
    subject.create_event("checkin_1111", simple_data)
    subject.remove_event("checkin_1111")
    subject.event_for("checkin_1111").should == Hash.new
  end

  it "updates an event" do
    data = simple_data
    subject.create_event("checkin_1111", data)

    data["hotness"] = "So new!"
    subject.update_event("checkin_1111", data)

    subject.event_for("checkin_1111").should eq(data)
  end

  it "creates a new timeline event" do
    key = "gizmo_1111"
    token = [Time.now.tv_sec, key].join('_')
    data = {"gizmo" => MultiJson.encode({"message" => "I'm here!"})}
    subject.create_event(key, data)
    subject.create_timeline_event("_global", token, key)

    subject.timeline_for("_global").should ==({token => key})
    subject.timeline_events_for("_global").values.should == [key]
  end

  it "creates timeline events without duplicates if timestamps match" do
    key = "gizmo_1111"
    token = [Time.now.tv_sec, key].join('_')
    subject.create_timeline_event("_global", token, key)
    subject.create_timeline_event("_global", token, key)

    subject.timeline_events_for("_global").length.should == 1
  end

  it "fetches timeline events with a count parameter" do
    tokens = 15.times.inject({}) { |result, i|
      key = "gizmo_#{i}"
      token = [Time.now.tv_sec, key].join('_')

      subject.create_timeline_event("_global", token, key)
      result.update(token => key)
    }.sort_by { |token, key| token }

    events = subject.timeline_for("_global", :per_page => 10)
    events.length.should == 10
    events.sort_by { |token, key| token }.should == tokens.slice(5, 10)
  end

  it "fetches timeline events from a page offset" do
    pending('rewrite to work with real cassandra and mocked cassandra')
    uuids = 15.times.map { subject.new_guid }.reverse
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      subject.create_timeline_event("_global", uuid, ref)
    end

    offset = uuids[10]
    subject.timeline_for("_global", :page => offset).length.should == 5
  end

  it "fetches timeline events with a count and offset parameter" do
    pending('rewrite to work with real cassandra and mocked cassandra')
    uuids = 15.times.map { subject.new_guid }
    uuids.each_with_index do |uuid, i|
      ref = "gizmo_#{i}"
      subject.create_timeline_event("_global", uuid, ref)
    end

    subject.timeline_for("_global", :per_page => 10, :page => uuids[11]).length.should == 10
    subject.timeline_for("_global", :per_page => 10, :page => uuids[4]).length.should == 5#, "doesn't truncate when length(count+offset) > length(results)"
  end

  it "does not fetch an empty array of timelines" do
    reject_multiget

    subject.timeline_for([]).should == Hash.new
  end

  it "fetches an extra item when a page parameter is specified and truncates appropriately" do
    pending('rewrite to work with real cassandra and mocked cassandra')
    uuids = 15.times.inject({}) { |result, i|
      uuid = subject.new_guid
      ref = "gizmo_#{i}"

      subject.create_timeline_event("_global", uuid, ref)
      result.update(uuid => ref)
    }.sort_by { |uuid, ref| uuid }

    start = uuids[10][0]
    events = subject.timeline_for(
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

    subject.create_event("gizmo_1111", data)
    subject.create_timeline_event("_global", token, key)
    subject.remove_timeline_event("_global", token)

    subject.timeline_events_for("_global").values.should == []
  end

  def reject_multiget
    subject.should_receive(:objects).exactly(0).times
  end

  def simple_data
    {"checkin" => MultiJson.encode({"message" => "I'm here!"})}
  end

end
