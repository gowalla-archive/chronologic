require "time"

class Chronologic::Protocol
  attr_accessor :schema

  def record(event_key, data)
    schema.create_object(event_key, data)
  end

  def unrecord(event_key)
    schema.remove_object(event_key)
  end

  def subscribe(timeline_key, subscriber_key)
    schema.create_subscription(timeline_key, subscriber_key)

    event_keys = schema.timeline_for(subscriber_key)
    event_keys.each do |guid, event_key| 
      schema.create_timeline_event(timeline_key, guid, event_key) 
    end
  end

  def unsubscribe(timeline_key, subscriber_key)
    schema.remove_subscription(timeline_key, subscriber_key)
    schema.timeline_for(subscriber_key).each do |guid, event_key|
      schema.remove_timeline_event(timeline_key, guid)
    end
  end

  def publish(event)
    schema.create_event(event.key, event.to_columns)
    uuid = schema.new_guid
    all_timelines = [event.timelines, schema.subscribers_for(event.timelines)].flatten
    all_timelines.map { |t| schema.create_timeline_event(t, uuid, event.key) }
  end

  def feed(timeline_key, fetch_subevents=false)
    # TODO: return a Hashie::Dash
    event_keys = schema.timeline_events_for(timeline_key)
    events = schema.event_for(event_keys)

    subevents = {}
    if fetch_subevents
      subevent_keys = schema.timeline_events_for(event_keys)
      result = schema.event_for(subevent_keys.values.flatten).values
      subevents = result.inject({}) do |hsh, subevent|
        parent = subevent["data"]["parent"]
        if hsh.has_key?(parent)
          hsh[parent] << subevent
        else
          hsh[parent] = [subevent]
        end
        hsh
      end
    end
    
    object_keys = [events.values, subevents.values].flatten.map do |e|
      e["objects"].values
    end
    objects = schema.object_for(object_keys.flatten)

    # TODO: we can do better than returning a dumb hash
    events.map do |event_key, e|
      # This is horribly unclear
      objs = e["objects"].inject({}) do |hsh, (slot, key)|
        hsh.update(slot => objects[key])
      end

      subs = {}
      if fetch_subevents
        subs = subevents[event_key]
        subs.each do |sub|
          sub["objects"] = sub["objects"].clone.inject({}) do |hsh, (slot, key)|
            hsh.update(slot => objects[key])
          end
        end
      end

      e.update("objects" => objs, "subevents" => subs)
    end
  end

end

require "hashie/dash"

class Chronologic::Event < Hashie::Dash

  property :key
  property :timestamp
  property :data
  property :objects
  property :timelines

  def to_columns
    raise NestedDataError.new if data_is_nested?
    {
      "timestamp" => timestamp.utc.iso8601,
      "data" => data,
      "objects" => objects
    }
  end

  def data_is_nested?
    data.values.any? { |v| v.is_a?(Hash) || v.is_a?(Array) || v.is_a?(Set) }
  end

end

