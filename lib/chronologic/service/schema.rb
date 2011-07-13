require "cassandra/0.7"

module Chronologic::Service::Schema
  mattr_accessor :write_opts 
  mattr_accessor :logger

  self.write_opts = {:consistency => Cassandra::Consistency::QUORUM}

  def self.create_object(key, attrs)
    log "create_object(#{key})"

    connection.insert(:Object, key, attrs, write_opts)
  end

  def self.remove_object(object_key)
    log("remove_object(#{object_key})")

    connection.remove(:Object, object_key, write_opts)
  end

  def self.object_for(object_key)
    log("object_for(#{object_key})")

    case object_key
    when String
      connection.get(:Object, object_key)
    when Array
      return {} if object_key.empty?
      connection.multi_get(:Object, object_key)
    end
  end

  def self.create_subscription(timeline_key, subscriber_key, backlink_key='')
    log("create_subscription(#{timeline_key}, #{subscriber_key}, #{backlink_key})")

    connection.insert(:Subscription, subscriber_key, {timeline_key => backlink_key}, write_opts)
  end

  def self.remove_subscription(timeline_key, subscriber_key)
    log("remove_subscription(#{timeline_key}, #{subscriber_key}")

    connection.remove(:Subscription, subscriber_key, timeline_key)
  end

  def self.subscribers_for(timeline_key)
    log("subscribers_for(#{timeline_key})")

    case timeline_key
    when String
      connection.get(:Subscription, timeline_key).keys
    when Array
      return [] if timeline_key.empty?
      connection.multi_get(:Subscription, timeline_key).map { |k, v| v.keys }.flatten
    end
  end

  def self.followers_for(timeline_key)
    connection.get(:Subscription, timeline_key).values
  end

  def self.create_event(event_key, data)
    log("create_event(#{event_key})")

    connection.insert(:Event, event_key, data, write_opts)
  end

  def self.update_event(event_key, data)
    log("update_event(#{event_key})")

    connection.insert(:Event, event_key, data, write_opts)
  end

  def self.remove_event(event_key)
    log("remove_event(#{event_key})")

    connection.remove(:Event, event_key)
  end

  def self.event_for(event_key)
    log("event_for(#{event_key.inspect})")

    case event_key
    when Array
      return {} if event_key.empty?
      connection.multi_get(:Event, event_key)
    when String
      connection.get(:Event, event_key)
    end
  end

  def self.create_timeline_event(timeline, uuid, event_key)
    log("create_timeline_event(#{timeline}, #{uuid}, #{event_key})")

    connection.insert(:Timeline, timeline, {uuid => event_key}, write_opts)
  end

  def self.timeline_for(timeline, options={})
    log("timeline_for(#{timeline}, #{options.inspect})")

    count = options[:per_page] || 20
    start = options[:page] || nil # Cassandra seems OK with a nil offset

    case timeline
    when String
      if start.nil? # First page
        connection.get(
          :Timeline, 
          timeline, 
          :start => start, 
          :count => count, 
          # AKK: it would be nice to figure out how not to need to reverse
          # this so that clients don't have to reverse it again to get
          # reverse-chronological listings
          :reversed => true
        )
      else # nth page, need cleverness
        results = connection.get(
          :Timeline,
          timeline,
          :start => start,
          :count => count + 1,
          # AKK: it would be nice to figure out how not to need to reverse
          # this so that clients don't have to reverse it again to get
          # reverse-chronological listings
          :reversed => true
        )
        count >= results.length ? results : Hash[*results.drop(1).flatten]
      end
    when Array
      return {} if timeline.empty?
      connection.multi_get(:Timeline, timeline)
    end
  end

  def self.timeline_events_for(timeline, options={})
    log("timeline_events_for(#{timeline})")

    case timeline
    when String
      timeline_for(timeline, options)
    when Array
      timeline_for(timeline).inject({}) do |hsh, (timeline_key, column)| 
        hsh.update(timeline_key => column.values)
      end
    end
  end

  def self.remove_timeline_event(timeline, uuid)
    log("remove_timeline_event(#{timeline}, #{uuid})")

    connection.remove(:Timeline, timeline, uuid)
  end

  def self.timeline_count(timeline)
    connection.count_columns(:Timeline, timeline)
  end

  def self.new_guid(timestamp=Time.now)
    SimpleUUID::UUID.new(timestamp.stamp).to_guid
  end

  def self.connection
    Chronologic.connection
  end

  def self.log(msg)
    return unless logger
    logger.debug(msg)
  end

end

