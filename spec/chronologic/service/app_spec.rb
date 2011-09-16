require 'spec_helper'
require 'rack/test'

describe Chronologic::Service::App do
  include Rack::Test::Methods

  let(:protocol) { Chronologic::Service::Protocol }

  it "writes a new entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }

    post "/object", {:object_key => "spot_1", :data => data}

    last_response.status.should == 201
    Chronologic.schema.object_for("spot_1").should == data
  end

  it "reads an entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }
    protocol.record("spot_1", data)

    get "/object/spot_1"

    last_response.status.should == 200
    json_body.should == data
  end

  it "deletes an entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }
    protocol.record("spot_1", data)

    delete "/object/spot_1"

    last_response.status.should == 204
    Chronologic.schema.object_for("spot_1").should == Hash.new
  end

  it "subscribes a subscriber to a timeline" do
    subscription = {
      "timeline_key" => "user_1_home",
      "subscriber_key" => "user_2",
      "backlink_key" => "user_1"
    }

    post "/subscription", subscription

    last_response.status.should == 201
    Chronologic.schema.subscribers_for("user_2").should include("user_1_home")
    Chronologic.schema.followers_for("user_2").should include("user_1")
  end

  it "subscribes a subscriber to a timeline without backfill" do
    Chronologic.schema.create_timeline_event('user_2', 'abc123', 'event_1')

    subscription = {
      "timeline_key" => "user_1_home",
      "subscriber_key" => "user_2",
      "backlink_key" => "user_1",
      "backfill" => "false"
    }

    post "/subscription", subscription

    last_response.status.should == 201
    Chronologic.schema.subscribers_for("user_2").should include("user_1_home")
    Chronologic.schema.followers_for("user_2").should include("user_1")
    Chronologic.schema.timeline_for("user_1_home").length.should == 0
  end

  it "unsubscribes a subscriber to a timeline" do
    protocol.subscribe("user_2", "user_1_home")

    delete "/subscription/user_2/user_1_home"

    last_response.status.should == 204
    Chronologic.schema.subscribers_for("user_2").should_not include("user_1_home")
  end

  it 'checks social connection for a timeline backlink and a subscriber key' do
    # Set up connections
    protocol.subscribe('user_bo_feed', 'user_ak', 'user_bo') # w/ backlink
    protocol.subscribe('user_ak_feed', 'user_bo', 'user_ak')
    protocol.subscribe('user_bs_feed', 'user_bo', 'user_bs') # No recip.

    get '/subscription/is_connected', {
      'timeline_backlink' => 'user_ak',
      'subscriber_key' => 'user_bo'
    }

    last_response.status.should == 200
    obj = JSON.load(last_response.body)
    obj['user_bo'].should == true
  end

  context "POST /event" do

    it "publishes an event" do
      event = {
        "key" => "checkin_1212",
        "data" => JSON.dump({"type" => "checkin", "message" => "I'm here!"}),
        "objects" => JSON.dump({"user" => "user_1", "spot" => "spot_1"}),
        "timelines" => JSON.dump(["user_1", "spot_1"])
      }

      post "/event", event

      last_response.status.should == 201

      result = Chronologic.schema.event_for("checkin_1212")
      result["data"].should == event["data"]
      result["objects"].should == event["objects"]

      last_response.headers["Location"].should match(%r!/event/#{event["key"]}!)
    end

    it "returns an error if a duplicate event is published" do
      event = {
        "key" => "checkin_1212",
        "data" => JSON.dump({"type" => "checkin", "message" => "I'm here!"}),
        "objects" => JSON.dump({"user" => "user_1", "spot" => "spot_1"}),
        "timelines" => JSON.dump(["user_1", "spot_1"])
      }

      post "/event?fanout=0", event
      post "/event?fanout=0", event

      last_response.status.should == 409
      last_response.body.should match(/duplicate event/)
    end

    it "publishes an event without fanout" do
      event = {
        "key" => "checkin_1212",
        "data" => JSON.dump({"type" => "checkin", "message" => "I'm here!"}),
        "objects" => JSON.dump({"user" => "user_1", "spot" => "spot_1"}),
        "timelines" => JSON.dump(["user_1", "spot_1"])
      }
      protocol.subscribe("user_1_home", "user_1")

      post "/event?fanout=0", event

      last_response.status.should == 201

      result = Chronologic.schema.event_for("checkin_1212")
      result["data"].should == event["data"]
      result["objects"].should == event["objects"]
      Chronologic.schema.timeline_events_for("user_1_home").values.should_not include(event["key"])
    end

    it "publishes an event with a forced timestamp" do
      event = {
        "key" => "checkin_1212",
        "data" => JSON.dump({"type" => "checkin", "message" => "I'm here!"}),
        "objects" => JSON.dump({"user" => "user_1", "spot" => "spot_1"}),
        "timelines" => JSON.dump(["user_1", "spot_1"])
      }
      t = Time.now.tv_sec - 120

      post "/event?fanout=0&force_timestamp=#{t}", event

      last_response.status.should == 201
      Chronologic.schema.timeline_events_for('user_1').keys.should include("#{t}_checkin_1212")
    end

  end

  it "unpublishes an event" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]
    uuid = protocol.publish(event)

    delete "/event/checkin_1111"

    last_response.status.should == 204
    Chronologic.schema.event_for("checkin_1111").should == Hash.new
  end

  it "updates an event" do
    event = simple_event
    protocol.publish(event)

    put "/event/#{event.key}", event.to_transport

    last_response.status.should eq(204)
    last_response.headers["Location"].should match(%r!/event/#{event["key"]}!)
  end

  it "updates an event and its timelines" do
    event = simple_event
    protocol.publish(event)
    event.timelines << 'foo_1'

    put "/event/#{event.key}?update_timelines=true", event.to_transport

    last_response.status.should eq(204)
    Chronologic.schema.timeline_events_for('foo_1').values.should include(event['key'])
    last_response.headers["Location"].should match(%r!/event/#{event["key"]}!)
  end

  it 'fetches a single event' do
    event = simple_event
    uuid = protocol.publish(event)

    get "/event/#{event.key}"

    last_response.status.should == 200
    json_body.should include('event')
    json_body['event'].should_not include('timestamp')
    json_body['event'].should include('key', 'data', 'timelines', 'objects')
  end

  it "returns 404 if an event isn't found" do
    get "/event/thingy_123"
    last_response.status.should == 404
  end

  it "reads a timeline feed with a non-default strategy" do
    Chronologic::Service::ObjectlessFeed.should_receive(:create).and_return(double.as_null_object)
    get "/timeline/user_1_home?strategy=objectless"
  end

  it "reads a timeline feed" do
    jp = {"name" => "Juan Pelota's", "awesome_factor" => "100"}
    keeg = {"name" => "Keegan", "awesome_factor" => "109"}
    protocol.record("spot_1", jp)
    protocol.record("user_1", keeg)

    protocol.subscribe("user_1_home", "user_1")
    event = simple_event
    uuid = protocol.publish(event)

    get "/timeline/user_1_home"

    last_response.status.should == 200
    obj = json_body
    obj["feed"].length.should == 1

    result = obj["feed"].first
    result["data"].should == event.data
    result["objects"]["user"].should == keeg
    result["objects"]["spot"].should == jp
  end

  it "reads a timeline feed with page and per_page parameters" do
    populate_timeline

    get "/timeline/user_1_home", :per_page => 5

    json_body.should have_key("next_page")
    # We're cheating on counts for a while
    # json_body["count"].should eq(10)
    json_body["feed"].length.should == 5
  end

  it "reads a timeline with subevents" do
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

    get "/timeline/user_1_home", :subevents => true
    obj = json_body
    result = obj["feed"].first
    result["subevents"].length.should == 2
  end

  def json_body
    JSON.load(last_response.body)
  end

  def app
    logger = Logger.new(STDOUT)
    logger.level = Logger::WARN
    Chronologic::Service::App.logger = logger
    Chronologic::Service::App.new
  end

end
