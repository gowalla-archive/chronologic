class Chronologic::Service::Schema::Memory

  SubscriptionInfo = Struct.new(:fanout_timeline, :backlink)

  attr_reader :objects, :subscriptions, :events, :timelines

  def initialize
    @objects = {}
    @subscriptions = Hash.new { |hsh, k| hsh[k] = [] }
    @events = {}
    @timelines = Hash.new { |hsh, k| hsh[k] = {} }
  end

  def create_object(key, attrs)
    objects[key] = attrs
  end

  def object_for(key)
    case key
    when String
      objects.fetch(key, {})
    when Array
      key.inject({}) { |hsh, k| hsh.update(k => objects[k]) }
    end
  end

  def remove_object(key)
    objects.delete(key)
  end

  def create_subscription(fanout_timeline, publisher_timeline, backlink='')
    sub = SubscriptionInfo.new(fanout_timeline, backlink)
    subscriptions[publisher_timeline] << sub
  end

  def subscribers_for(publisher_timeline)
    case publisher_timeline
    when String
      subscriptions[publisher_timeline].map { |s| s.fanout_timeline }
    when Array
      publisher_timeline.map { |t| subscribers_for(t) }.flatten
    end
  end

  def followers_for(publisher_timeline)
    subscriptions[publisher_timeline].map { |s| s.backlink }
  end

  def remove_subscription(fanout_timeline, publisher_timeline)
    subscriptions[publisher_timeline].delete_if { |s| s.fanout_timeline == fanout_timeline }
  end

  def create_event(event_key, data)
    events[event_key] = data
  end

  def event_exists?(event_key)
    events.has_key?(event_key)
  end

  def event_for(event_key)
    case event_key
    when String
      events.fetch(event_key, {})
    when Array
      event_key.inject({}) { |hsh, k| hsh.update(k => event_for(k)) }
    end
  end

  def each_event(start='')
    sorted_events = events.sort_by { |(key, event)| key }

    sorted_events.each do |key, event| 
      next if key < start
      yield(key, event)
    end
  end

  def remove_event(event_key)
    events.delete(event_key)
  end

  def update_event(event_key, data)
    events[event_key] = data
  end

  def create_timeline_event(timeline, token, event_key)
    timelines[timeline][token] = event_key
  end

  def timeline_for(timeline, options={})
    case timeline
    when String
      raw_timeline = timelines.fetch(timeline, {})
      extract_range(raw_timeline, options)
    when Array
      return {} if timeline.empty?
    end
  end

  def timeline_events_for(timeline, options={})
    case timeline
    when String
      timeline_for(timeline, options)
    end
  end

  def remove_timeline_event(timeline, token)
    timelines[timeline].delete(token)
  end

  # Private
  def extract_range(raw_timeline, options={})
    count = options.fetch(:count, 10)

    entries = raw_timeline.
      sort_by { |k, v| k }.
      reverse.
      first(count)

    Hash[entries]
  end

end

