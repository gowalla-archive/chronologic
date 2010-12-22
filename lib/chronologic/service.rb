require "sinatra/base"
require "active_support/core_ext/class"

# TODO: caching headers?
class Chronologic::Service < Sinatra::Base

  cattr_accessor :logger

  post "/object" do
    protocol.record(params["object_key"], params["data"])
    status 201
  end

  get "/object/:object_key" do
    # FIXME: stomping on Demeter here
    status 200
    json protocol.schema.object_for(params["object_key"])
  end

  delete "/record/:object_key" do
    protocol.unrecord(params["object_key"])
    status 204
  end

  post "/subscription" do
    protocol.subscribe(params["timeline_key"], params["subscriber_key"])
    status 201
  end

  delete "/subscription/:subscriber_key/:timeline_key" do
    protocol.unsubscribe(params["subscriber_key"], params["timeline_key"])
    status 204
  end

  post "/event" do
    uuid = protocol.publish(event)
    headers("Location" => "/event/#{params["key"]}/#{uuid}")
    status 201
  end

  delete "/event/:event_key/:uuid" do
    raw_event = protocol.schema.event_for(params["event_key"])
    event = Chronologic::Event.new(raw_event)
    event.key = params["event_key"]
    protocol.unpublish(event, params["uuid"])
    status 204
  end

  get "/timeline/:timeline_key" do
    subevents = params["subevents"] == "true"
    feed = protocol.feed(params["timeline_key"], subevents)
    status 200
    json("feed" => feed)
  end

  helpers do

    def json(object)
      content_type("application/json")
      JSON.dump(object)
    end

    def event
      timestamp = Time.parse(params["timestamp"])
      Chronologic::Event.new(params.update("timestamp" => timestamp))
    end

    def protocol
      Chronologic::Protocol
    end

  end

  before do
    @timer = Time.now
  end

  after do
    time = "%.3fms" % [Time.now - @timer]
    logger.info "#{request.request_method} #{request.path}: #{time}"
  end

  disable :dump_errors
  disable :show_exceptions

  error do
    exception = env["sinatra.error"]

    logger.error "Error: #{exception.message} (#{exception.class})"
    logger.error exception.backtrace.join("\n  ")

    "Chronologic error: #{exception.message}"
  end

end

