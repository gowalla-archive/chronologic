require "time"

class Chronologic::Protocol
  attr_accessor :schema

  def record(event_key, data)
    schema.create_object(event_key, data)
  end

  def subscribe(timeline_key, subscriber_key)
    schema.create_subscription(timeline_key, subscriber_key)
  end

  # Should event be a proper object?
  def publish(event_key, timestamp, data, objects, timelines)
    columns = {
      "timestamp" => timestamp.utc.iso8601,
      # Note: this hash can only be one dimensional; nested hashes get ingloriously squashed
      "data" => data,
      "objects" => objects
    }
    schema.create_event(event_key, columns)
    all_timelines = [timelines, schema.subscribers_for(timelines)].flatten
    all_timelines.map { |t| schema.create_timeline_event(t, event_key) }
  end

  def feed(timeline_key)
    event_keys = schema.timeline_events_for(timeline_key)
    events = schema.event_for(event_keys)

    object_keys = events.map { |e| e["objects"].values }.flatten
    objects = schema.object_for(object_keys)

    # TODO: we can do better than returning a dumb hash
    events.map do |e|
      # This is horribly unclear
      objects = e["objects"].inject({}) do |hsh, (slot, key)|
        hsh.update(slot => objects[key])
      end
      e.update("objects" => objects)
    end
  end

end

