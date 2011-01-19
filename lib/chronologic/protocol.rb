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
    Chronologic::Feed.fetch(timeline_key, options)
  end
  
  def self.feed_count(timeline_key)
    schema.timeline_count(timeline_key)
  end

  def self.schema
    Chronologic.schema
  end

end

