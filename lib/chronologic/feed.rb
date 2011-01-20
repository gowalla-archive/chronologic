class Chronologic::Feed

  def self.create(timeline_key, options={})
    fetch_subevents = options[:fetch_subevents]
    count = options[:per_page] || 20
    start = options[:page] || nil

    feed = new(timeline_key, count, start, fetch_subevents)
  end

  attr_accessor :timeline_key, :per_page, :start, :subevents
  attr_accessor :previous_page, :next_page, :count

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

    self.previous_page = uuids.first
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
    object_keys = [events].flatten.map { |e| e.objects.values }
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
    end
  end

  def bind_objects(refs, objects)
    refs.inject({}) do |hsh, (slot, key)|
      hsh.update(slot => objects[key])
    end
  end

  def bind_subevents(event_key, refs, objects)
    return [] unless subevents

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
