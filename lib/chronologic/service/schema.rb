module Chronologic::Service::Schema
  mattr_accessor :write_opts 
  mattr_accessor :consistent_read_opts
  mattr_accessor :logger

  self.write_opts = {:consistency => Cassandra::Consistency::QUORUM}
  self.consistent_read_opts = {:consistency => Cassandra::Consistency::QUORUM}

  MAX_SUBSCRIPTIONS = 50_000
  MAX_TIMELINES = 50_000

  def self.create_object(key, attrs)
    log("create_object(#{key}, #{attrs.inspect})")

    connection.insert(:Object, key, attrs, write_opts)
  end

  def self.remove_object(object_key)
    log("remove_object(#{object_key})")

    connection.remove(:Object, object_key, write_opts)
  end

  def self.object_for(object_key)
    log("object_for(#{object_key})")

    # Note: this will only pull 100 columns for objects. This seems like a
    # reasonable default, but we'll look back at this comment some day and
    # laugh. ~AKK
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
      connection.get(:Subscription, timeline_key, :count => MAX_SUBSCRIPTIONS).keys
    when Array
      return [] if timeline_key.empty?
      connection.multi_get(:Subscription, timeline_key, :count => MAX_SUBSCRIPTIONS).map { |k, v| v.keys }.flatten
    end
  end

  def self.followers_for(timeline_key)
    log("followers_for(#{timeline_key})")
    connection.get(:Subscription, timeline_key, :count => MAX_SUBSCRIPTIONS).values
  end

  def self.create_event(event_key, data)
    log("create_event(#{event_key}, #{data.inspect})")

    connection.insert(:Event, event_key, data, write_opts)
  end

  def self.update_event(event_key, data)
    log("update_event(#{event_key}, #{data.inspect})")

    connection.insert(:Event, event_key, data, write_opts)
  end

  def self.remove_event(event_key)
    log("remove_event(#{event_key})")

    connection.remove(:Event, event_key, write_opts)
  end

  def self.event_exists?(event_key)
    log("event_exists?(#{event_key.inspect})")

    connection.exists?(:Event, event_key, consistent_read_opts)
  end

  def self.event_for(event_key)
    log("event_for(#{event_key.inspect})")

    # Note: this will only pull 100 columns for events. This seems like a
    # reasonable default, but we'll look back at this comment some day and
    # laugh. ~AKK
    case event_key
    when Array
      return {} if event_key.empty?
      connection.multi_get(:Event, event_key, consistent_read_opts)
    when String
      connection.get(:Event, event_key, consistent_read_opts)
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
    # Used to use connection.count_columns here, but it doesn't seem
    # to respect the :count option. There is a fix for this in rjackson's fork,
    # need to see if its merged into fauna and included in a release. ~AKK

    # But in the meantime, nothing in Gowalla is using the page count so we're
    # going to hardcode this obviously incorrect value for the time being.
    -1
  end

  # Lookup events on the specified timeline(s) and return all the events
  # referenced by those timelines.
  #
  # timeline_keys - one or more String timeline_keys to fetch events from
  #
  # Returns a flat array of events
  def self.fetch_timelines(timeline_keys, per_page=20, page='')
    event_keys = timeline_events_for(
      timeline_keys,
      :per_page => per_page,
      :page => page
    ).values.flatten

    event_for(event_keys.uniq).
      map do |k, e|
        Chronologic::Event.load_from_columns(e).tap do |event|
          event.key = k
        end
      end
  end

  # Fetch objects referenced by events and correctly populate the event objects
  #
  # events - an array of Chronologic::Event objects to populate
  #
  # Returns a flat array of Chronologic::Event objects with their object
  # references populated.
  def self.fetch_objects(events)
    object_keys = events.map { |e| e.objects.values }.flatten.uniq
    objects = object_for(object_keys)
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

  # Convert a flat array of Chronologic::Events into a properly hierarchical
  # timeline.
  #
  # events - an array of Chronologic::Event objects, each possibly referencing
  # other events
  #
  # Returns a flat array of Chronologic::Event objects with their subevent
  # references correctly populated.
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

  def self.batch
    connection.batch { yield }
  end

  def self.connection
    Chronologic.connection
  end

  def self.log(msg)
    return unless logger
    logger.debug(msg)
  end

end

