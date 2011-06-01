require "helper"

describe Chronologic::Client do

  before do
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

    @client.subscribe("user_1_home", "user_2", "user_1").must_equal true
    assert_requested :post,
      "http://localhost:3000/subscription",
      :body => {
        "subscriber_key" => "user_1_home", 
        "timeline_key" => "user_2",
        "backlink_key" => "user_1"
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

    event = simple_event

    body = event.to_transport
    stub_request(:post, "http://localhost:3000/event?fanout=1").
      with(:body => body).
      to_return(
        :status => 201, 
        :headers => {"Location" => "/event/checkin_1/#{guid}"}
      )

    @client.publish(event, true).must_match /[\w\d-]*/
    event.published?.must_equal true
    assert_requested :post, 
      "http://localhost:3000/event?fanout=1", 
      :body => body
  end

  it "unpublishes an event" do
    event_key = "checkin_1"
    stub_request(
      :delete,
      "http://localhost:3000/event/#{event_key}"
    ).to_return(:status => 204)

    @client.unpublish(event_key).must_equal true
    assert_requested :delete, "http://localhost:3000/event/#{event_key}"
  end

  it "fetches a timeline" do
    event = simple_event

    stub_request(:get, "http://localhost:3000/timeline/user_1_home?subevents=false&page=abc-123&per_page=5").
      to_return(
        :status => 200, 
        :body => {"feed" => [event]}.to_json,
        :headers => {"Content-Type" => "application/json"}
    )

    result = @client.timeline("user_1_home", :subevents => false, :page => "abc-123", :per_page => "5")
    assert_requested :get, "http://localhost:3000/timeline/user_1_home?subevents=false&page=abc-123&per_page=5"
    result["feed"].length.must_equal 1
    result["items"].total_entries.must_equal 1
    (result["feed"].first.keys - ["timestamp"]).each do |k|
      result["feed"].first[k].must_equal event[k]
    end
  end

  it "fetches a timeline with subevents" do
    event = simple_event
    event["subevents"] = [nested_event]
    
    stub_request(:get, "http://localhost:3000/timeline/user_1_home?subevents=true").
      to_return(
        :status => 200,
        :body => {"feed" => [event]}.to_json,
        :headers => {"Content-Type" => "application/json"}
      )

    result = @client.timeline("user_1_home", :subevents => true)
    assert_requested :get, "http://localhost:3000/timeline/user_1_home?subevents=true"
    result["items"].first["subevents"].length.must_equal 1
  end

  it "provides an instance of itself" do
    Chronologic::Client.instance = @client
    Chronologic::Client.instance.must_equal @client
  end
end

