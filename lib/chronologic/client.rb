require "active_support/core_ext/class"
require "will_paginate/array"
require "httparty"

class Chronologic::Client

  include HTTParty

  cattr_accessor :instance

  def initialize(host)
    self.class.default_options[:base_uri] = host
  end

  def record(object_key, data)
    body = {"object_key" => object_key, "data" => data}
    resp = self.class.post("/object", :body => body)

    handle(resp, "Error creating new record") do
      true
    end
  end

  def unrecord(object_key)
    resp = self.class.delete("/object/#{object_key}")

    handle(resp, "Error removing record") do
      true
    end
  end

  def subscribe(subscriber_key, timeline_key, backlink_key=nil)
    body = {
      "subscriber_key" => subscriber_key,
      "timeline_key" => timeline_key
    }
    body['backlink_key'] = backlink_key unless backlink_key.nil?

    resp = self.class.post("/subscription", :body => body)

    handle(resp, "Error creating subscription") do
      true
    end
  end

  def unsubscribe(subscriber_key, timeline_key)
    resp = self.class.delete("/subscription/#{subscriber_key}/#{timeline_key}")

    handle(resp, "Error removing subscription") do
      true
    end
  end

  def publish(event, fanout=true)
    resp = self.class.post(
      "/event", 
      :query => {:fanout => fanout ? 1 : 0}, 
      :body => event.to_transport
    )
    event.published!

    handle(resp, "Error publishing event") do
      resp.headers["Location"]
    end
  end

  def unpublish(event_key)
    resp = self.class.delete("/event/#{event_key}")

    handle(resp, "Error unpublishing event") do
      true
    end
  end

  def timeline(timeline_key, options={})
    resp = if options.length > 0
             self.class.get("/timeline/#{timeline_key}", :query => options)
           else
             self.class.get("/timeline/#{timeline_key}")
           end

    handle(resp, "Error fetching timeline") do
      {
        "feed" => resp["feed"],
        "count" => resp["count"],
        "next_page" => resp["next_page"],
        "items" => resp["feed"].
          map { |v| Chronologic::Event.new(v) }.
          paginate(:total_entries => resp["count"])
      }
    end
  end

  def handle(response, message)
    if response.code == 500 && response.content_type == 'application/json'
      raise Chronologic::ServiceError.new(JSON.load(response.body))
    elsif response.code < 200 || response.code > 299
      raise Chronologic::Exception.new(message)
    elsif block_given?
      yield(response)
    end
  end

end

