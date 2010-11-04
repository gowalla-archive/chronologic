require "helper"
require "fakeweb"

describe Chronologic::Client do

  before do
    @protocol = Chronologic::Protocol.new
    @protocol.schema = chronologic_schema
    @client = Chronologic::Client.new('http://localhost:3000')
  end

  it "records an entity" do
    stub_request(:post, "http://localhost:3000/object").
      to_return(:status => 201)

    @client.record("user_1", {"name" => "akk"}).must_equal true
    assert_requested :post,
      "http://localhost:3000/object",
      :body => {"object_key" => "user_1", "data" => {"name" => "akk"}}
  end

  it "unrecords an entity" do
    stub_request(:delete, "http://localhost:3000/object/spot_1").
      to_return(:status => 204)

    @client.unrecord("spot_1").must_equal true
    assert_requested :delete, "http://localhost:3000/object/spot_1"
  end

  it "subscribes a user to a timeline" do
    stub_request(:post, "http://localhost:3000/subscription").
      to_return(:status => 201)

    @client.subscribe("user_1_home", "user_2").must_equal true
    assert_requested :post,
      "http://localhost:3000/subscription",
      :body => {
        "subscriber_key" => "user_1_home", 
        "timeline_key" => "user_2"
      }
  end

  it "unsubscribes a user to a timeline" do
    stub_request(
      :delete, 
      "http://localhost:3000/subscription/user_1_home/user_2"
    ).to_return(:status => 204)

    @client.unsubscribe("user_1_home", "user_2").must_equal true
    assert_requested :delete,
      "http://localhost:3000/subscription/user_1_home/user_2"
  end

  it "publishes an event" do
    guid = SimpleUUID::UUID.new.to_guid

    event = Chronologic::Event.new
    event.key = "checkin_1"
    event.timestamp = Time.now.utc.iso8601
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    stub_request(:post, "http://localhost:3000/event").
      with(:body => event.to_hash).
      to_return(
        :status => 201, 
        :headers => {"Location" => "/event/checkin_1/#{guid}"}
      )

    @client.publish(event).must_match /[\w\d-]*/
    assert_requested :post, 
      "http://localhost:3000/event", 
      :body => event.to_hash
  end

  it "unpublishes an event" do
    event_key = "checkin_1"
    uuid = "A6047FBA-045C-4649-8525-984C5C1266AF"
    stub_request(
      :delete,
      "http://localhost:3000/event/#{event_key}/#{uuid}"
    ).to_return(:status => 204)

    @client.unpublish(event_key, uuid).must_equal true
    assert_requested :delete, "http://localhost:3000/event/#{event_key}/#{uuid}"
  end

  it "fetches a timeline" do
    event = Chronologic::Event.new
    event.key = "checkin_1"
    event.timestamp = Time.now.utc.iso8601
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    stub_request(:get, "http://localhost:3000/timeline/user_1_home").
      to_return(
        :status => 200, 
        :body => {"feed" => [event]}.to_json,
        :headers => {"Content-Type" => "application/json"}
    )

    result = @client.timeline("user_1_home")
    assert_requested :get, "http://localhost:3000/timeline/user_1_home"
    result.length.must_equal 1
    (result.first.keys - ["timestamp"]).each do |k|
      result.first[k].must_equal event[k]
    end
  end

  it "provides an instance of itself" do
    Chronologic::Client.instance = @client
    Chronologic::Client.instance.must_equal @client
  end
end

