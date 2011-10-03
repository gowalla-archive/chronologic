require "hashie/dash"
require "time"

class Chronologic::Event < Hashie::Dash

  property :key
  property :token
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
      "token" => token,
      "data" => MultiJson.encode(data),
      "objects" => MultiJson.encode(objects),
      "timelines" => MultiJson.encode(timelines)
    }
  end

  def to_transport
    to_columns.update("key" => key).tap do |col|
      col.delete("token")
    end
  end

  def to_client_encoding
    {
      "key" => key,
      "data" => data,
      "objects" => objects,
      "timelines" => timelines,
      "subevents" => subevents
    }
  end

  def self.load_from_columns(columns)
    to_load = {
      "data" => MultiJson.decode(columns.fetch("data", '{}')),
      "objects" => MultiJson.decode(columns.fetch("objects", '{}')),
      "timelines" => MultiJson.decode(columns.fetch("timelines", '[]')),
      "token" => columns.fetch('token', '')
    }

    new(to_load)
  end

  def set_token(force_timestamp=false)
    timestamp = if force_timestamp
      force_timestamp
    else
      Time.now.utc.tv_sec
    end
    self.token = [timestamp, key].join('_')
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

  def empty?
    data.empty?
  end

end

