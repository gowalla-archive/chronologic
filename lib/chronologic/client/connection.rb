require "active_support/core_ext/module"
require 'active_support/core_ext/hash'
require "will_paginate/array"
require "httparty"

class Chronologic::Client::Connection

  include HTTParty

  mattr_accessor :instance

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

  def subscribe(subscriber_key, timeline_key, backlink_key=nil, backfill=true)
    body = {
      # The names above are consistent with how subscriptions work. They
      # are transposed below for consistency with the service API, which needs
      # to change for consistency's sake.
      "subscriber_key" => timeline_key, # TODO: FIXME!  notice what's going on here and fix it on the service end
      "timeline_key" => subscriber_key # TODO: FIXME!  notice what's going on here and fix it on the service end
    }
    body['backlink_key'] = backlink_key unless backlink_key.nil?
    body['backfill'] = false unless backfill

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

  def connected?(subscriber_key, backlink_key)
    body = {
      'subscriber_key' => subscriber_key,
      'timeline_backlink' => backlink_key
    }
    resp = self.class.get('/subscription/is_connected', :query => body)

    handle(resp, "Error checking connectedness") do
      resp.body.fetch('subscriber_key', false)
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

  def fetch(event_url)
    resp = self.class.get(event_url)

    handle(resp, "Error fetching event") do
      # FIXME: use #children instead?
      Chronologic::Event.new(resp['event']).tap do |ev|
        ev.subevents = ev.subevents.map { |sub| Chronologic::Event.new(sub) }
      end
    end
  end

  def update(event, update_timelines=false)
    resp = self.class.put(
      "/event/#{event.key}",
      :query => {:update_timelines => update_timelines},
      :body => event.to_transport
    )
    event.published!

    handle(resp, "Error updating event") do
      resp.headers["Location"]
    end
  end

  def timeline(timeline_key, options={})
    resp = if options.length > 0
             self.class.get("/timeline/#{timeline_key}", :query => options)
           else
             self.class.get("/timeline/#{timeline_key}")
           end

    handle(resp, "Error fetching timeline") do
      items = resp["feed"].map do |ev|
        # FIXME: use #children instead?
        Chronologic::Event.new(ev).tap do |e|
          e.subevents = e.subevents.map { |sub| Chronologic::Event.new(sub) }
        end
      end
      {
        "feed" => resp["feed"],
        "count" => resp["count"],
        "next_page" => resp["next_page"],
        "items" => items
      }.with_indifferent_access
    end
  end

  def handle(response, message)
    if response.code == 500 && response.content_type == 'application/json'
      raise Chronologic::ServiceError.new(JSON.load(response.body))
    elsif response.code == 409
      raise Chronologic::Duplicate.new(response.body)
    elsif response.code == 404
      raise Chronologic::NotFound.new
    elsif response.code > 400
      raise Chronologic::Exception.new(message)
    elsif response.code < 400 && block_given?
      yield(response)
    end
  end

end

