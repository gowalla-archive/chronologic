require "helper"

class Sxsw
  include Chronologic::Subscriber
end

describe Chronologic::Subscriber do

  before do
    Chronologic::Client.instance = 
      Chronologic::Client.new('http://localhost:3000')
    @sxsw = Sxsw.new
  end

  it "adds helper methods" do
    @sxsw.methods.must_include "timeline"
    @sxsw.methods.must_include "subscribe"
    @sxsw.methods.must_include "unsubscribe"
  end

  it "returns a paginated array" do
    stub_request(:get, "http://localhost:3000/timeline/sxsw").
      to_return(
        :status => 200, 
        :body => {"feed" => [simple_event], "count" => 20}.to_json, 
        :headers => {"Content-Type" => "application/json"}
      )

    @sxsw.timeline("sxsw")["items"].total_entries.must_equal 20
    assert_requested :get, "http://localhost:3000/timeline/sxsw"
  end

  it "fetches a timeline" do
    stub_request(:get, "http://localhost:3000/timeline/sxsw").
      to_return(
        :status => 200, 
        :body => {"feed" => [simple_event]}.to_json, 
        :headers => {"Content-Type" => "application/json"}
      )

    @sxsw.timeline("sxsw")["feed"].length.must_equal 1
    assert_requested :get, "http://localhost:3000/timeline/sxsw"
  end

  it "fetches a nested timeline" do
    event = simple_event
    event["subevents"] = [nested_event]
    stub_request(:get, "http://localhost:3000/timeline/sxsw?subevents=true&page=abc-123&per_page=5").
      to_return(
        :status => 200,
        :body => {"feed" => [event]}.to_json,
        :headers => {"Content-Type" => "application/json"}
      )

    result = @sxsw.timeline("sxsw", :subevents => true, :page => "abc-123", :per_page => 5)
    assert_requested :get, "http://localhost:3000/timeline/sxsw?subevents=true&page=abc-123&per_page=5"
    result["items"].first["subevents"].length.must_equal 1
  end

  it "subscribes to a timeline" do
    stub_request(:post, "http://localhost:3000/subscription").
      to_return(:status => 201)

    @sxsw.subscribe("sxsw", "spot_1")
    assert_requested :post, "http://localhost:3000/subscription"
  end

  it "unsubscribes from a timeline" do
    stub_request(:delete, "http://localhost:3000/subscription/sxsw/spot_1").
      to_return(:status => 204)

    @sxsw.unsubscribe("sxsw", "spot_1")
    assert_requested :delete, "http://localhost:3000/subscription/sxsw/spot_1"
  end


end
