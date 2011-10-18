require 'spec_helper'

describe Chronologic::Client::Connection do

  let(:client) { Chronologic::Client::Connection.new('http://localhost:3000') }

  it "records an object" do
    stub_request(:post, "http://localhost:3000/object").
      to_return(:status => 201)

    client.record("user_1", {"name" => "akk"}).should be_true
    WebMock.should have_requested(:post, "http://localhost:3000/object").
      with(:body => {"object_key" => "user_1", "data" => {"name" => "akk"}})
  end

  it "unrecords an object" do
    stub_request(:delete, "http://localhost:3000/object/spot_1").
      to_return(:status => 204)

    client.unrecord("spot_1").should be_true
    WebMock.should have_requested(:delete, "http://localhost:3000/object/spot_1")
  end

  it "retrieves an object" do
    object = {
      'test' => 'abc'
    }

    stub_request(
      :get,
      "http://localhost:3000/object/spot_1"
    ).to_return(
      :status => 200,
      :body => object.to_json,
      :headers => {'Content-Type' => 'application/json'}
    )

    result = client.retrieve("spot_1")
    WebMock.should have_requested(
      :get,
      "http://localhost:3000/object/spot_1"
    )
    result.should eq(object)
  end

  it "subscribes a user to a timeline" do
    stub_request(:post, "http://localhost:3000/subscription").
      to_return(:status => 201)

    client.subscribe("user_2", "user_1_home", "user_1").should be_true
    WebMock.should have_requested(:post, "http://localhost:3000/subscription").
      with(
        :body => {
          "subscriber_key" => "user_1_home",
          "timeline_key" => "user_2",
          "backlink_key" => "user_1",
          "backfill" => "true"
        }
      )
  end

  it 'subscribes a user to a timline without performing backfill' do
    stub_request(:post, "http://localhost:3000/subscription").
      to_return(:status => 201)

    client.subscribe("user_2", "user_1_home", "user_1", false).should be_true
    WebMock.should have_requested(:post, "http://localhost:3000/subscription").
      with(
        :body => {
          "subscriber_key" => "user_1_home",
          "timeline_key" => "user_2",
          "backlink_key" => "user_1",
          "backfill" => "false"
        }
      )
  end

  it "unsubscribes a user to a timeline" do
    stub_request(
      :delete,
      "http://localhost:3000/subscription/user_1_home/user_2"
    ).to_return(:status => 204)

    client.unsubscribe("user_1_home", "user_2").should be_true
    WebMock.should have_requested(:delete, "http://localhost:3000/subscription/user_1_home/user_2")
  end

  it "checks whether a feed is connected to another feed" do
    query = {
      'subscriber_key' => 'user_ak',
      'timeline_backlink' => 'user_bf'
    }.map { |pair| pair.join('=') }.join('&')

    resp = {
      'subscriber_key' => true
    }
    stub_request(:get, "http://localhost:3000/subscription/is_connected?#{query}").
      to_return(
        :status => 200,
        :body => resp
      )

    client.connected?('user_ak', 'user_bf').should be_true
    WebMock.should have_requested(:get, "http://localhost:3000/subscription/is_connected?#{query}")
  end

  it "publishes an event" do
    event = simple_event(:client)
    t = Time.now.utc.tv_sec

    body = event.to_transport
    stub_request(:post, "http://localhost:3000/event?fanout=1&force_timestamp=#{t}").
      with(:body => body).
      to_return(
        :status => 201,
        :headers => {"Location" => "/event/checkin_1"}
      )

    client.publish(event, true, t).should match(/[\w\d-]*/)
    event.should be_published
    WebMock.should have_requested(:post, "http://localhost:3000/event?fanout=1&force_timestamp=#{t}").
      with(:body => body)
  end

  it "unpublishes an event" do
    event_key = "checkin_1"
    stub_request(
      :delete,
      "http://localhost:3000/event/#{event_key}"
    ).to_return(:status => 204)

    client.unpublish(event_key).should be_true
    WebMock.should have_requested(:delete, "http://localhost:3000/event/#{event_key}")
  end

  it 'updates an event' do
    event = simple_event(:client)

    url = "http://localhost:3000/event/#{event.key}?update_timelines=false"
    body = event.to_transport
    stub_request(:put, url).
      with(:body => body).
      to_return(
        :status => 201,
        :headers => {"Location" => "/event/checkin_1/abc123"}
      )

    client.update(event, false).should eq("/event/checkin_1/abc123")
    WebMock.should have_requested(:put, url).
      with(:body => body)
  end

  it 'updates an event with timeline changes' do
    event = simple_event(:client)

    url = "http://localhost:3000/event/#{event.key}?update_timelines=true"
    body = event.to_transport
    stub_request(:put, url).
      with(:body => body).
      to_return(
        :status => 201,
        :headers => {"Location" => "/event/checkin_1/abc123"}
      )

    client.update(event, true).should eq("/event/checkin_1/abc123")
    WebMock.should have_requested(:put, url).
      with(:body => body)
  end

  it "fetches an event" do
    event = simple_event(:client)

    stub_request(
      :get,
      "http://localhost:3000/events/#{event.key}"
    ).to_return(
      :status => 200,
      :body => {'event' => simple_event(:client)}.to_json,
      :headers => {'Content-Type' => 'application/json'}
    )

    result = client.fetch("/events/#{event.key}")
    WebMock.should have_requested(
      :get,
      "http://localhost:3000/events/#{event.key}"
    )
    result.should be_a(Chronologic::Event)
  end

  it "fetches a timeline" do
    event = simple_event

    stub_request(:get, "http://localhost:3000/timeline/user_1_home?subevents=false&page=abc-123&per_page=5").
      to_return(
        :status => 200,
        :body => {"feed" => [event.to_client_encoding]}.to_json,
        :headers => {"Content-Type" => "application/json"}
    )

    result = client.timeline("user_1_home", :subevents => false, :page => "abc-123", :per_page => "5")
    WebMock.should have_requested(:get, "http://localhost:3000/timeline/user_1_home?subevents=false&page=abc-123&per_page=5")
    result["feed"].length.should == 1
    (result["feed"].first.keys - ["timestamp"]).each do |k|
      result["feed"].first[k].should == event.send(k)
    end
  end

  it "fetches a timeline with subevents" do
    event = simple_event
    event.subevents = [nested_event]

    stub_request(:get, "http://localhost:3000/timeline/user_1_home?subevents=true").
      to_return(
        :status => 200,
        :body => {"feed" => [event.to_client_encoding]}.to_json,
        :headers => {"Content-Type" => "application/json"}
      )

    result = client.timeline("user_1_home", :subevents => true)
    WebMock.should have_requested(:get, "http://localhost:3000/timeline/user_1_home?subevents=true")
    result["items"].first["subevents"].length.should == 1
  end

  it "provides an instance of itself" do
    Chronologic::Client::Connection.instance = client
    Chronologic::Client::Connection.instance.should == client
  end

  context "#handle" do

    it "parses JSON errors" do
      resp = double(
        :response,
        :code => 500,
        :content_type => 'application/json',
        :body => MultiJson.encode({})
      )

      expect { client.handle(resp, 'message') }.to raise_exception(Chronologic::ServiceError)
    end

    it "parses duplicate errors" do
      resp = double(:response, :code => 409, :body => 'duplicate!')
      expect { client.handle(resp, 'message') }.to raise_exception(Chronologic::Duplicate)
    end

    it "parses not found errors" do
      resp = double(:response, :code => 404)
      expect { client.handle(resp, 'message') }.to raise_exception(Chronologic::NotFound)
    end

    it "parses generic errors" do
      resp = double(:response, :code => 500, :content_type => 'text/plain')
      expect { client.handle(resp, 'message') }.to raise_exception(Chronologic::Exception)
    end

    it "yields on success" do
      called = false
      resp = double(:response, :code => 201)
      client.handle(resp, 'boom') { called = true }
      called.should be_true
    end

  end

end

