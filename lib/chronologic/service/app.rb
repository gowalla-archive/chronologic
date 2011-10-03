require "sinatra/base"
require "active_support/core_ext/class"
require "yajl"

# TODO: caching headers?
class Chronologic::Service::App < Sinatra::Base

  cattr_accessor :logger

  post "/object" do
    log_params

    protocol.record(params["object_key"], params["data"])
    status 201
  end

  get "/object/:object_key" do
    log_params

    # FIXME: stomping on Demeter here
    status 200
    json protocol.schema.object_for(params["object_key"])
  end

  delete "/object/:object_key" do
    log_params

    protocol.unrecord(params["object_key"])
    status 204
  end

  post "/subscription" do
    log_params

    protocol.subscribe(
      params["timeline_key"],
      params["subscriber_key"],
      params.fetch("backlink_key") { '' },
      params["backfill"] == "true"
    )
    status 201
  end

  delete "/subscription/:subscriber_key/:timeline_key" do
    log_params

    protocol.unsubscribe(params["subscriber_key"], params["timeline_key"])
    status 204
  end

  get '/subscription/is_connected' do
    log_params

    connection = protocol.connected?(
      params['subscriber_key'],
      params['timeline_backlink']
    )

    status(200)
    json(params['subscriber_key'] => connection)
  end

  post "/event" do
    log_params

    begin
      fanout = params.fetch("fanout", "") == "1"
      force_timestamp = params.fetch("force_timestamp", false)
      protocol.publish(event, fanout, force_timestamp)

      headers("Location" => "/event/#{params["key"]}")
      status 201
    rescue Chronologic::Duplicate
      body("Could not create duplicate event, did you mean to update it?")
      status 409
    end
  end

  delete "/event/:event_key" do
    log_params

    raw_event = protocol.schema.event_for(params["event_key"])
    if raw_event.empty?
      status 204
      return
    end
    event = Chronologic::Event.load_from_columns(raw_event)
    event.key = params["event_key"]
    protocol.unpublish(event)
    status 204
  end

  get '/event/:event_key' do
    log_params

    begin
      options = {}
      options[:strategy] = params.fetch("strategy", "default").to_sym
      event = protocol.fetch_event(params['event_key'], options)
      json('event' => event.to_client_encoding)
    rescue Chronologic::NotFound => e
      status 404
    end
  end

  put '/event/:event_key' do
    log_params

    update_timelines = if params.fetch('update_timelines', '') == "true"
      true
    else
      false
    end
    protocol.update_event(event, update_timelines)
    headers("Location" => "/event/#{event.key}")
    status 204
  end

  get "/timeline/:timeline_key" do
    log_params

    options = {
      :fetch_subevents => params["subevents"] == "true",
      :page => params["page"] || nil,
      :per_page => Integer(params["per_page"] || "20")
    }
    options.update(:strategy => params["strategy"]) if params.has_key?("strategy")
    feed = protocol.feed(params["timeline_key"], options)

    status 200
    json(
      "feed" => feed.items,
      "count" => feed.count,
      "next_page" => feed.next_page
    )
  end

  helpers do

    def log_params
      logger.debug "Params: #{params.inspect}"
    end

    def json(object)
      content_type("application/json")
      Yajl.dump(object)
    end

    def event
      Chronologic::Event.new(
        "key" => params["key"],
        "data" => JSON.load(params["data"]),
        "objects" => JSON.load(params["objects"]),
        "timelines" => JSON.load(params["timelines"])
      )
    end

    def protocol
      Chronologic::Service::Protocol
    end

  end

  before do
    @timer = Time.now
  end

  after do
    time = "%.3fs" % [Time.now - @timer]
    logger.info "#{request.request_method} #{request.path}: #{time}"
  end

  disable :dump_errors
  disable :show_exceptions

  error do
    exception = env["sinatra.error"]

    logger.error "Error: #{exception.message} (#{exception.class})"
    logger.error "Params: #{params.inspect}"
    logger.error exception.backtrace.join("\n  ")

    status 500
    json({
      "exception_class" => exception.class,
      "message" => exception.message,
      "backtrace" => exception.backtrace.take(20),
      "params" => params
    })
  end

end

