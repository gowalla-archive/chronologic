require "helper"
require "fakeweb"

describe Chronologic::Client do

  before do
    @protocol = Chronologic::Protocol.new
    @protocol.schema = chronologic_schema
    @client = Chronologic::Client.new('http://localhost:3000')
    FakeWeb.allow_net_connect = false
  end

  it "records an entity" do
    FakeWeb.register_uri(
      :post, 
      "http://localhost:3000/record", 
      :status => 201
    )

    @client.record("user_1", {"name" => "akk"}).must_equal true
  end

  it "unrecords an entity" do
    FakeWeb.register_uri(
      :delete, 
      "http://localhost:3000/record/spot_1", 
      :status => 204
    )

    @client.unrecord("spot_1").must_equal true
  end

  it "subscribes a user to a timeline" do
    FakeWeb.register_uri(
      :post,
      "http://localhost:3000/subscription",
      :status => 201
    )

    @client.subscribe("user_1_home", "user_2").must_equal true
  end

  it "unsubscribes a user to a timeline" do
    FakeWeb.register_uri(
      :delete,
      "http://localhost:3000/subscription/user_1_home/user_2",
      :status => 204
    )

    @client.unsubscribe("user_1_home", "user_2").must_equal true
  end

  it "publishes an event" do
    guid = SimpleUUID::UUID.new.to_guid
    FakeWeb.register_uri(
      :post,
      "http://localhost:3000/event",
      :status => 201,
      :location => "/event/checkin_1/#{guid}"
    )

    event = Chronologic::Event.new
    event.key = "checkin_1"
    event.timestamp = Time.now.utc.iso8601
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @client.publish(event).must_match /[\w\d-]*/
    # TODO: verify request parameters via FakeWeb.last_request
  end

  it "unpublishes an event" do
    event_key = "checkin_1"
    uuid = "A6047FBA-045C-4649-8525-984C5C1266AF"
    FakeWeb.register_uri(
      :delete,
      "http://localhost:3000/event/#{event_key}/#{uuid}",
      :status => 204
    )

    @client.unpublish(event_key, uuid).must_equal true
  end

  it "fetches a timeline" do
    event = Chronologic::Event.new
    event.key = "checkin_1"
    event.timestamp = Time.now.utc.iso8601
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    FakeWeb.register_uri(
      :get,
      "http://localhost:3000/timeline/user_1_home",
      :body => [event].to_json,
      :content_type => "application/json"
    )

    result = @client.timeline("user_1_home")
    result.length.must_equal 1
    (result.first.keys - ["timestamp"]).each do |k|
      result.first[k].must_equal event[k]
    end
  end

end

