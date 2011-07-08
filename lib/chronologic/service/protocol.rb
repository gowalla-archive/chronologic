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
    Chronologic::Event.load_from_columns(schema.event_for(event_key)).tap do |ev|
      ev.key = event_key
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

end

