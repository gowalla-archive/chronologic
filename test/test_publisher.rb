require "helper"

class Checkin
  include Chronologic::Publisher
end

describe Chronologic::Publisher do

  before do
    Chronologic::Client.instance = 
      Chronologic::Client.new('http://localhost:3000')
    @checkin = Checkin.new
  end

  it "adds helper methods" do
    @checkin.methods.must_include "publish"
    @checkin.methods.must_include "unpublish"
  end

  it "publishes events" do
    # FIXME: needing to do this here is a little hacky
    stub_request(:post, "http://localhost:3000/event").
      to_return(:status => 201)

    event = Chronologic::Event.new
    event.key = "checkin_1"
    event.timestamp = Time.now.utc
    event.data = {"type" => "checkin", "message" => "I'm here!"}
    event.objects = {"user" => "user_1", "spot" => "spot_1"}
    event.timelines = ["user_1", "spot_1"]

    @checkin.publish(event)
    assert_requested :post, "http://localhost:3000/event", :body => /checkin_1/
  end

  it "unpublishes event" do
    uuid = "A6047FBA-045C-4649-8525-984C5C1266AF"
    stub_request(:delete, "http://localhost:3000/event/checkin_1/#{uuid}").
      to_return(:status => 204)
    
    @checkin.unpublish("checkin_1", uuid)
    assert_requested :delete, "http://localhost:3000/event/checkin_1/#{uuid}"
  end

end
