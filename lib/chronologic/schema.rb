require "cassandra"

module Chronologic::Schema

  def self.create_object(key, attrs)
    connection.insert(:Object, key, attrs)
  end

  def self.remove_object(object_key)
    connection.remove(:Object, object_key)
  end

  def self.object_for(object_key)
    case object_key
    when String
      connection.get(:Object, object_key)
    when Array
      connection.multi_get(:Object, object_key)
    end
  end

  def self.create_subscription(timeline_key, subscriber_key)
    connection.insert(:Subscription, subscriber_key, {timeline_key => ''})
  end

  def self.remove_subscription(timeline_key, subscriber_key)
    connection.remove(:Subscription, subscriber_key, timeline_key)
  end

  def self.subscribers_for(timeline_key)
    case timeline_key
    when String
      connection.get(:Subscription, timeline_key).keys
    when Array
      connection.multi_get(:Subscription, timeline_key).map { |k, v| v.keys }.flatten
    end
  end

  def self.create_event(event_key, data)
    connection.insert(:Event, event_key, data)
  end

  def self.remove_event(event_key)
    connection.remove(:Event, event_key)
  end

  def self.event_for(event_key)
    case event_key
    when Array
      connection.multi_get(:Event, event_key)
    when String
      connection.get(:Event, event_key)
    end
  end

  def self.create_timeline_event(timeline, uuid, event_key)
    connection.insert(:Timeline, timeline, {uuid => event_key})
  end

  def self.timeline_for(timeline, options={})
    count = options[:per_page] || 20
    start = options[:page] || nil # Cassandra seems OK with a nil offset

    case timeline
    when String
      connection.get(:Timeline, timeline, :start => start, :count => count)
    when Array
      connection.multi_get(:Timeline, timeline)
    end
  end

  def self.timeline_events_for(timeline, options={})
    case timeline
    when String
      timeline_for(timeline, options).values
    when Array
      timeline_for(timeline).inject({}) do |hsh, (timeline_key, column)| 
        hsh.update(timeline_key => column.values)
      end
    end
  end

  def self.remove_timeline_event(timeline, uuid)
    connection.remove(:Timeline, timeline, uuid)
  end

  def self.new_guid
    SimpleUUID::UUID.new.to_guid
  end

  def self.connection
    Chronologic.connection
  end

end

