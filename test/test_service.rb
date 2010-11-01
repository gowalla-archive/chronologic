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

  it "publishes an event"

  it "unpublishes an event"

  it "reads a timeline feed"

  def json_body
    JSON.load(last_response.body)
  end

  def app
    Chronologic::Service.new(@protocol)
  end

end
