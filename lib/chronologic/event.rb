require "hashie/dash"
require "time"

class Chronologic::Event < Hashie::Dash

  property :key
  property :timestamp
  property :data, :default => {}
  property :objects, :default => {}
  property :timelines, :default => []
  property :subevents, :default => []

  def initialize(*args)
    @published = false
    super(*args)
  end

  def to_columns
    {
      "timestamp" => timestamp.utc.iso8601,
      "data" => JSON.dump(data),
      "objects" => JSON.dump(objects),
      "timelines" => JSON.dump(timelines)
    }
  end

  def to_transport
    to_columns.update("key" => key)
  end

  def self.load_from_columns(columns)
    # XXX this is so janky
    raw_time = columns['timestamp']
    timestamp = raw_time.is_a?(DateTime) ? raw_time : (Time.parse(raw_time) rescue nil)

    to_load = {
      "data" => JSON.load(columns.fetch("data", '{}')),
      "objects" => JSON.load(columns.fetch("objects", '{}')),
      "timelines" => JSON.load(columns.fetch("timelines", '[]')),
      "timestamp" => timestamp
    }

    new(to_load)
  end

  def subevent?
    data.has_key?("parent")
  end

  def parent
    data["parent"]
  end

  def parent=(parent)
    data["parent"] = parent
  end

  def published?
    @published
  end

  def published!
    @published = true
  end

  # Public: converts the event's subevents to Chronologic::Event objects
  #
  # Returns an array of Chronologic::Event objects.
  def children
    @children ||= subevents.map { |s| Chronologic::Event.new(s) }
  end

  def token
    # XXX janky jank-sauce
    Chronologic.schema.new_guid(timestamp)
  end

  def empty?
    data.empty?
  end

end

