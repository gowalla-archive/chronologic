require "helper"

describe Chronologic::Service do
  include Rack::Test::Methods

  before do
    @protocol = Chronologic::Protocol.new
    @protocol.schema = chronologic_schema
  end

  it "writes a new entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }

    post "/record", {:key => "spot_1", :data => data}

    last_response.status.must_equal 201
    @protocol.schema.object_for("spot_1").must_equal data
  end

  it "reads an entity record" do
    data = {
      "name" => "Juan Pelota's", 
      "awesome_factor" => "100"
    }
    @protocol.record("spot_1", data)

    get "/record/spot_1"

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
    @protocol.schema.object_for("spot_1").must_equal Hash.new
  end

  it "subscribes a subscriber to a timeline" do
    subscription = {
      "timeline_key" => "user_1_home",
      "subscriber_key" => "user_2",
    }

    post "/subscription", subscription

    last_response.status.must_equal 201
    @protocol.schema.subscribers_for("user_2").must_include "user_1_home"
  end

  it "unsubscribes a subscriber to a timeline" do
    @protocol.subscribe("user_2", "user_1_home")

    delete "/subscription/user_2/user_1_home"

    last_response.status.must_equal 204
    @protocol.schema.subscribers_for("user_2").wont_include "user_1_home"
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

    result = @protocol.schema.event_for("checkin_1212")
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
    @protocol.schema.event_for("checkin_1111").must_equal Hash.new
  end

  it "reads a timeline feed"

  def json_body
    JSON.load(last_response.body)
  end

  def app
    Chronologic::Service.new(@protocol)
  end

end
