require "rubygems"
require "minitest/spec"
MiniTest::Unit.autorun

require "chronologic"

describe Chronologic::Schema do 

  before do
    @schema = Chronologic::Schema.new
    @schema.connection = Cassandra.new("Chronologic")
    @schema.connection.clear_keyspace!
  end

  it "creates an object" do
    attrs = {"name" => "akk"}
    @schema.create_object("user_1", attrs)

    @schema.object_for("user_1").must_equal attrs
  end

  it "updates an object"
  it "removes an object"

  it "creates a subscription" do
    @schema.create_object("user_1", {"name" => "akk"})
    @schema.create_object("user_2", {"name" => "sco"})
    @schema.create_subscription("user_1", "user_2")

    @schema.subscribers_for("user_1").must_equal ["user_2"]
    @schema.subscriptions_for("user_2").must_equal ["user_1"]
  end

  it "removes a subscription"

  it "publishes an event" do
    data = {"checkin" => {"message" => "I'm here!"}}

    @schema.create_event("checkin_1111", data)
    @schema.event_for("checkin_1111").must_equal data
  end

  it "removes an event"

  it "publishes a simple event to a timeline" do
    data = {"gizmo" => {"message" => "I'm here!"}}
    @schema.create_event("gizmo_1111", data)
    @schema.publish("_global", "gizmo_1111")

    @schema.timeline_for("_global").must_equal ["gizmo_1111"]
  end

end

