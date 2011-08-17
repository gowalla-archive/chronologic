require "time"
require "hashie/mash"

module Chronologic::Service::Protocol
  SUBSCRIBE_BACKFILL_COUNT = 20

  def self.record(event_key, data)
    schema.create_object(event_key, data)
  end

  def self.unrecord(event_key)
    schema.remove_object(event_key)
  end

  # Subscribe timeline_key to events created on subscriber_key and copy events 
  # from subscriber_key to timeline_key
  def self.subscribe(timeline_key, subscriber_key, backlink_key='', backfill=true)
    schema.create_subscription(timeline_key, subscriber_key, backlink_key)
    return unless backfill

    event_keys = schema.timeline_for(
      subscriber_key, 
      :per_page => SUBSCRIBE_BACKFILL_COUNT
    )
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

  def self.connected?(timeline_key, backlink_key)
    schema.followers_for(timeline_key).include?(backlink_key)
  end

  def self.publish(event, fanout=true)
    schema.create_event(event.key, event.to_columns)
    uuid = schema.new_guid(event.timestamp)

    all_timelines = [event.timelines]
    if fanout
      all_timelines << schema.subscribers_for(event.timelines)
    end

    all_timelines.
      flatten.
      map { |t| schema.create_timeline_event(t, uuid, event.key) }
    event.published!
    uuid
  end

  def self.unpublish(event)
    uuid = schema.new_guid(event.timestamp)
    schema.remove_event(event.key)
    raw_timelines = event.timelines
    # FIXME: this is a hackish way to handle both event objects and events
    # pulled from Cassandra
    timelines = raw_timelines.respond_to?(:keys) ? raw_timelines.keys : raw_timelines
    all_timelines = [timelines, schema.subscribers_for(timelines)].flatten
    all_timelines.map { |t| schema.remove_timeline_event(t, uuid) }
  end

  def self.fetch_event(event_key)
    event = Chronologic::Event.load_from_columns(schema.event_for(event_key)).tap do |ev|
      ev.key = event_key
    end

    subevents = EventGraph.fetch_timelines([event.key])
    populated_events = EventGraph.fetch_objects([event, subevents].flatten)
    EventGraph.reify_timeline(populated_events).first
  end

  def self.update_event(event, update_timelines=false)
    schema.update_event(event.key, event.to_columns)

    if update_timelines
      event.timelines.each { |t| schema.create_timeline_event(t, event.token, event.key) }
    end
  end

  def self.feed(timeline_key, options={})
    Chronologic::Service::Feed.create(timeline_key, options)
  end

  def self.feed_count(timeline_key)
    schema.timeline_count(timeline_key)
  end

  def self.schema
    Chronologic.schema
  end

  module EventGraph
    # TODO don't copy this so much, man

    def self.fetch_objects(events)
      object_keys = events.map { |e| e.objects.values }.flatten.uniq
      objects = schema.object_for(object_keys)
      events.map do |e|
        e.tap do
          e.objects.each do |type, keys|
            if keys.is_a?(Array)
              e.objects[type] = keys.map { |k| objects[k] }
            else
              e.objects[type] = objects[keys]
            end
          end
        end
      end
    end

    def self.fetch_timelines(timeline_keys)
      event_keys = schema.timeline_events_for(timeline_keys).values.flatten

      schema.
        event_for(event_keys.uniq).
        map do |k, e|
          Chronologic::Event.load_from_columns(e).tap do |event|
            event.key = k
          end
        end
    end

    def self.reify_timeline(events)
      event_index = events.inject({}) { |idx, e| idx.update(e.key => e) }
      timeline_index = events.inject([]) do |timeline, e|
        if e.subevent? && event_index.has_key?(e.parent)
          # AKK: something is weird about Hashie::Dash or Event in that if you 
          # push objects onto subevents, they are added to an object that is 
          # referenced by all instances of event. So, these dup'ing hijinks are 
          subevents = event_index[e.parent].subevents.dup
          subevents << e
          event_index[e.parent].subevents = subevents
        else
          timeline << e.key
        end
        timeline
      end
      timeline_index.map { |key| event_index[key] }
    end

    def self.schema
      Chronologic.schema
    end

  end

end

