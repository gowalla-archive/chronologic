require "httparty"

class Chronologic::Client

  include HTTParty

  def initialize(host)
    self.class.default_options[:base_uri] = host
  end

  def record(object_key, data)
    resp = self.class.post("/record", {"object_key" => object_key, "data" => data})
    raise Chronologic::Exception.new("Error creating new record") unless resp.code == 201
    true
  end

  def unrecord(object_key)
    resp = self.class.delete("/record/#{object_key}")
    raise Chronologic::Exception.new("Error removing record") unless resp.code == 204
    true
  end

  def subscribe(subscriber_key, timeline_key)
    body = {
      "subscriber_key" => subscriber_key,
      "timeline_key" => timeline_key
    }
    resp = self.class.post("/subscription", body)
    raise Chronologic::Exception.new("Error creating subscription") unless resp.code == 201
    true
  end

  def unsubscribe(subscriber_key, timeline_key)
    resp = self.class.delete("/subscription/#{subscriber_key}/#{timeline_key}")
    raise Chronologic::Exception.new("Error removing subscription") unless resp.code == 204
    true
  end

  def publish(event)
    raise Chronologic::Exception.new("Event data cannot contain nested values") if event.data_is_nested?
    resp = self.class.post("/event", event)
    raise Chronologic::Exception.new("Error publishing event") unless resp.code == 201
    url = resp.headers["Location"]
    url
  end

  def unpublish(event_key, uuid)
    resp = self.class.delete("/event/#{event_key}/#{uuid}")
    raise Chronologic::Exception.new("Error unpublishing event") unless resp.code == 204
    true
  end

  def timeline(timeline_key)
    resp = self.class.get("/timeline/#{timeline_key}")
    raise Chronologic::Exception.new("Error fetching timeline") unless resp.code == 200
    resp.parsed_response.map { |v| Chronologic::Event.new(v) }
  end

end

