require "sinatra/base"

# TODO: caching headers?
class Chronologic::Service < Sinatra::Base
  attr_accessor :connection

  def initialize(connection, *params)
    super(*params)
    self.connection = connection
  end

  post "/record" do
    connection.record(params["key"], params["data"])
    status 201
  end

  get "/record/:object_key" do
    # FIXME: stomping on Demeter here
    status 200
    json connection.schema.object_for(params["object_key"])
  end

  delete "/record/:object_key" do
    connection.unrecord(params["object_key"])
    status 204
  end

  post "/subscription" do
    connection.subscribe(params["timeline_key"], params["subscriber_key"])
    status 201
  end

  delete "/subscription/:subscriber_key/:timeline_key" do
    connection.unsubscribe(params["timeline_key"], params["subscriber_key"])
    status 204
  end

  post "/event" do
    uuid = connection.publish(event)
    headers("Location" => "/event/#{params["key"]}/#{uuid}")
    status 201
  end

  delete "/event/:event_key/:uuid" do
    raw_event = connection.schema.event_for(params["event_key"])
    event = Chronologic::Event.new(raw_event)
    event.key = params["event_key"]
    connection.unpublish(event, params["uuid"])
    status 204
  end

  get "/timeline/:timeline_key" do
    feed = connection.feed(params["timeline_key"])
    status 200
    json("feed" => feed)
  end

  helpers do

    def json(object)
      JSON.dump(object)
    end

    def event
      timestamp = Time.parse(params["timestamp"])
      Chronologic::Event.new(params.update("timestamp" => timestamp))
    end

  end

end
