require "helper"

describe Chronologic::Service do
  include Rack::Test::Methods

  before do
    @protocol = Chronologic::Protocol
  end

  it "writes a new entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }

    post "/object", {:object_key => "spot_1", :data => data}

    last_response.status.must_equal 201
    Chronologic.schema.object_for("spot_1").must_equal data
  end

  it "reads an entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }
    @protocol.record("spot_1", data)

    get "/object/spot_1"

    last_response.status.must_equal 200
    json_body.must_equal data
  end

  it "deletes an entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }
    @protocol.record("spot_1", data)

    delete "/record/spot_1"

    last_response.status.must_equal 204
    Chronologic.schema.object_for("spot_1").must_equal Hash.new
  end

  it "subscribes a subscriber to a timeline" do
    subscription = {
      "timeline_key" => "user_1_home",
      "subscriber_key" => "user_2",
    }

    post "/subscription", subscription

    last_response.status.must_equal 201
    Chronologic.schema.subscribers_for("user_2").must_include "user_1_home"
  end

  it "unsubscribes a subscriber to a timeline" do
    @protocol.subscribe("user_2", "user_1_home")

    delete "/subscription/user_2/user_1_home"

    last_response.status.must_equal 204
    Chronologic.schema.subscribers_for("user_2").wont_include "user_1_home"
  end

  it "publishes an event" do
    event = {
      "key" => "checkin_1212",
      "timestamp" => Time.now.utc.iso8601,
      "data" => {"type" => "checkin", "message" => "I'm here!"},
      "objects" => {"user" => "user_1", "spot" => "spot_1"},
      "timelines" => ["user_1", "spot_1"]
    }

    post "/event", event

    last_response.status.must_equal 201

    result = Chronologic.schema.event_for("checkin_1212")
    result["data"].must_equal event["data"]
    result["objects"].must_equal event["objects"]

    last_response.headers["Location"].must_match %r!/event/#{event["key"]}/[\d\w-]*!
  end

  it "unpublishes an event" do
    event = Chronologic::Event.new
    event.key = "checkin_1111"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]
    uuid = @protocol.publish(event)

    delete "/event/checkin_1111/#{uuid}"

    last_response.status.must_equal 204
    Chronologic.schema.event_for("checkin_1111").must_equal Hash.new
  end

  it "reads a timeline feed" do
    jp = {"name" => "Juan Pelota's", "awesome_factor" => "100"}
    keeg = {"name" => "Keegan", "awesome_factor" => "109"}
    @protocol.record("spot_1", jp)
    @protocol.record("user_1", keeg)

    @protocol.subscribe("user_1_home", "user_1")
    event = simple_event
    uuid = @protocol.publish(event)

    get "/timeline/user_1_home"

    last_response.status.must_equal 200
    obj = json_body
    obj["feed"].length.must_equal 1

    result = obj["feed"].first
    result["data"].must_equal event.data
    result["objects"]["user"].must_equal keeg
    result["objects"]["spot"].must_equal jp
  end

  it "reads a timeline with subevents" do
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

    get "/timeline/user_1_home", :subevents => true
    obj = json_body
    result = obj["feed"].first
    result["subevents"].length.must_equal 2
  end

  def json_body
    JSON.load(last_response.body)
  end

  def app
    logger = Logger.new(STDOUT)
    logger.level = Logger::WARN
    Chronologic::Service.logger = logger
    Chronologic::Service.new
  end

end
