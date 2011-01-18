require "time"
require "hashie/mash"

module Chronologic::Protocol

  def self.record(event_key, data)
    schema.create_object(event_key, data)
  end

  def self.unrecord(event_key)
    schema.remove_object(event_key)
  end

  def self.subscribe(timeline_key, subscriber_key)
    schema.create_subscription(timeline_key, subscriber_key)

    event_keys = schema.timeline_for(subscriber_key)
    event_keys.each do |guid, event_key| 
      schema.create_timeline_event(timeline_key, guid, event_key) 
    end
  end

  def self.unsubscribe(timeline_key, subscriber_key)
    schema.remove_subscription(timeline_key, subscriber_key)
    schema.timeline_for(subscriber_key).each do |guid, event_key|
      schema.remove_timeline_event(timeline_key, guid)
    end
  end

  def self.publish(event)
    schema.create_event(event.key, event.to_columns)
    uuid = schema.new_guid
    all_timelines = [event.timelines, schema.subscribers_for(event.timelines)].flatten
    all_timelines.map { |t| schema.create_timeline_event(t, uuid, event.key) }
    uuid
  end

  def self.unpublish(event, uuid)
    schema.remove_event(event.key)
    raw_timelines = event.timelines
    # FIXME: this is a hackish way to handle both event objects and events
    # pulled from Cassandra
    timelines = raw_timelines.respond_to?(:keys) ? raw_timelines.keys : raw_timelines
    all_timelines = [timelines, schema.subscribers_for(timelines)].flatten
    all_timelines.map { |t| schema.remove_timeline_event(t, uuid) }
  end

  def self.feed(timeline_key, options={})
    # AKK: this method really wants to get refactored
    
    fetch_subevents = options[:fetch_subevents]
    count = options[:per_page] || 20
    start = options[:page] || nil

    event_keys = schema.timeline_events_for(timeline_key, :per_page => count, :page => start)
    events = schema.event_for(event_keys).inject({}) { |hsh, (k, e)| hsh.update(k => Chronologic::Event.load_from_columns(e)) }

    subevents = {}
    if fetch_subevents
      subevent_keys = schema.timeline_events_for(event_keys)
      result = schema.event_for(subevent_keys.values.flatten).values
      subevents = result.inject({}) do |hsh, columns|
        subevent = Chronologic::Event.load_from_columns(columns)
        parent = subevent.data["parent"]
        if hsh.has_key?(parent)
          hsh[parent] << subevent
        else
          hsh[parent] = [subevent]
        end
        hsh
      end
    end
    
    object_keys = [events.values, subevents.values].flatten.map do |e|
      e.objects.values
    end
    objects = schema.object_for(object_keys.flatten)

    events.map do |event_key, e|
      event = Chronologic::Event.new
      event.key = event_key
      # FIXME: for some reason, the timestamps column ends up with multiple
      # values
      # event.timestamp = Time.parse(e["timestamp"])
      event.data = Hashie::Mash.new(e["data"])
      event.timelines = e["timelines"]

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

      event.objects = objs
      event.subevents = subs
      event
    end
  end
  
  def self.feed_count(timeline_key)
    schema.timeline_count(timeline_key)
  end

  def self.schema
    Chronologic.schema
  end

end

