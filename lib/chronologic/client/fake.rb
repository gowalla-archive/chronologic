class Chronologic::Client::Fake

  attr_reader :objects, :subscribers, :events, :timelines

  def initialize
    @objects = {}
    @subscribers = Hash.new { |hsh, k| hsh[k] = {} }
    @events = {}
    @timelines = Hash.new { |hsh, k| hsh[k] = {} }
  end

  def record(object_key, data)
    @objects[object_key] = data
  end

  def unrecord(object_key)
    @objects.delete(object_key)
  end

  def subscribe(subscriber_key, timeline_key, backlink_key=nil, backfill=true)
    @subscribers[subscriber_key][timeline_key] = backlink_key
    # XXX backfill
  end

  def unsubscribe(subscriber_key, timeline_key)
    @subscribers[subscriber_key].delete(timeline_key)
    # XXX unfill
  end

  def connected?(subscriber_key, backlink_key)
    @subscribers[subscriber_key].values.include?(backlink_key)
  end

  def publish(event)
    @events[event.key] = event
    event.timelines.each do |timeline|
      @timelines[timeline][SimpleUUID::UUID.new(event.timestamp)] = event.key
    end
    # XXX subscriber fanout

    event.key # Return something more like a real CL URL?
  end

  def unpublish(event)
    @events.delete(event.key)
    # XXX unfanout
  end

  def fetch(event_url)
    @events.fetch(event_url, {}).tap do |event|
      populate_subevents_for(event)
      populate_objects_for(event)
    end
  end

  def update(event, update_timelines=false)
    @events[event.key] = event
    # XXX update timelines
  end

  def timeline(timeline_key)
    # XXX read event keys from @timelines
    # XXX read events from @events
    # XXX read objects from @objects
    # XXX handle subevents
  end

  # Private
  def populate_objects_for(event)
    # At this point, objects is a hash of key -> array pairs. We need key -> hash.
    objects = Hash.new { |hsh, k| hsh[k] = Hash.new }
    event.objects.each do |k, refs|
      refs.each { |ref| objects[k][ref] = @objects[ref] }
    end
    event.objects = objects
  end

  # Private
  def populate_subevents_for(event)
    subevents = @timelines[event.key].values.map do |event_key|
      fetch(event_key)
    end
    event.subevents = subevents
  end

end
