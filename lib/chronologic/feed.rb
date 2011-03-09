class Chronologic::Feed

  def self.create(timeline_key, options={})
    fetch_subevents = options[:fetch_subevents]
    count = options[:per_page] || 20
    start = options[:page] || nil

    feed = new(timeline_key, count, start, fetch_subevents)
  end

  attr_accessor :timeline_key, :per_page, :start, :subevents
  attr_accessor :next_page, :count

  def initialize(timeline_key, per_page=20, start=nil, subevents=false)
    self.timeline_key = timeline_key
    self.per_page = per_page
    self.start = start
    self.subevents = subevents
  end

  def items
    return @items if @items

    event_index = schema.
      timeline_events_for(
        timeline_key,
        :per_page => per_page,
        :page => start
      )
    uuids = event_index.keys

    self.next_page = uuids.last
    self.count = schema.timeline_count(timeline_key)

    event_keys = event_index.values
    events = schema.
      event_for(event_keys).
      inject({}) do |hsh, (k, e)|
        hsh.update(k => Chronologic::Event.load_from_columns(e))
      end
    subs = fetch_subevents(event_keys)
    objects = fetch_objects(events.values + subs.values)
    @items = build_feed(events, subs, objects)
  end

  # Lookup events on the specified timeline(s) and return all the events
  # referenced by those timelines.
  #
  # timeline_keys - one or more String timeline_keys to fetch events from
  #
  # Returns a flat array of events
  def fetch_timelines(*timeline_keys)
    event_keys = schema.timeline_events_for(
      timeline_keys,
      :per_page => per_page,
      :page => start
    ).values.flatten

    # set next_page
    # set count

    schema.
      event_for(event_keys).
      map { |k, e| Chronologic::Event.load_from_columns(e) }
  end

  # Fetch objects referenced by events and correctly populate the event objects
  #
  # events - an array of Chronologic::Event objects to populate
  #
  # Returns a flat array of Chronologic::Event objects with their object
  # references populated.
  def fetch_objects_(*events)
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

  # Convert a flat array of Chronologic::Events into a properly hierarchical
  # timeline.
  #
  # events - an array of Chronologic::Event objects, each possibly referencing
  # other events
  #
  # Returns a flat array of Chronologic::Event objects with their subevent
  # references correctly populated.
  def reify_timeline(events)
    event_index = events.inject({}) { |idx, e| idx.update(e.key => e) }
    timeline_index = events.inject([]) do |timeline, e|
      if e.child?
        # AKK: something is weird about Hashie::Dash or Event in that if you push
        # objects onto subevents, they are added to an object that is referenced
        # by all instances of event. So, these dup'ing hijinks are required.
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

  def fetch_subevents(event_keys)
    return {} unless subevents

    subevent_keys = schema.timeline_events_for(event_keys).values.flatten
    events = schema.event_for(subevent_keys).values
    events.inject({}) do |hsh, columns|
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

  def fetch_objects(events)
    object_keys = [events].flatten.map { |e| e.objects.values }.flatten
    schema.object_for(object_keys.flatten.uniq)
  end

  def build_feed(events, subevents_, objects)
    events.map do |event_key, e|
      event = Chronologic::Event.new
      event.key = event_key
      event.timestamp = e["timestamp"]
      event.data = e["data"]
      event.timelines = e["timelines"]

      event.objects = bind_objects(e.objects, objects)
      event.subevents = bind_subevents(event_key, subevents_, objects)

      event
    end.sort_by { |e| e.timestamp }
  end

  def bind_objects(refs, objects)
    refs.inject({}) do |hsh, (slot, key)|
      if key.is_a?(Array)
        values = key.map { |k| objects[k] }
        hsh.update(slot => values)
      else
        hsh.update(slot => objects[key])
      end
    end
  end

  def bind_subevents(event_key, refs, objects)
    return [] unless subevents
    return [] unless refs.has_key?(event_key)

    refs[event_key].each do |sub|
      sub["objects"] = sub["objects"].clone.inject({}) do |hsh, (slot, key)|
        hsh.update(slot => objects[key])
      end
    end
  end

  def schema
    Chronologic::Schema
  end

end
