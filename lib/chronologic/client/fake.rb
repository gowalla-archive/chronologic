class Chronologic::Client::Fake

  def initialize
    @objects = {}
    @subscribers = Hash.new { |hsh, k| hsh[k] = {} }
    @events = {}
    @timelines = {}
  end

  def record(object_key, data)
    p "record: #{object_key}"
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
    p "publish: #{event.key}"
    p event
    @events[event.key] = event
    event.key # Return something more like a real CL URL?
    # XXX fanout
  end

  def unpublish(event)
    @events.delete(event.key)
    # XXX unfanout
  end

  def fetch(event_url)
    p "fetch: #{event_url}"
    @events.fetch(event_url, {}).tap do |event|
      # At this point, objects is a hash of key -> array pairs. We need key -> hash.
      objects = Hash.new { |hsh, k| hsh[k] = Hash.new }
      event.objects.each do |k, refs|
        refs.each { |ref| p "#{k} -> #{ref}"; p @objects[ref]; objects[k][ref] = @objects[ref]; objects }
      end
      event.objects = objects
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
end
