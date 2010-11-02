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

  it "subscribes a user to a timeline"

  it "unsubscribes a user to a timeline"

  it "publishes an event"

  it "unpublishes an event"

  it "fetches a timeline"

end
