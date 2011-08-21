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
      "data" => JSON.dump(data),
      "objects" => JSON.dump(objects),
      "timelines" => JSON.dump(timelines)
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
      "data" => JSON.load(columns.fetch("data", '{}')),
      "objects" => JSON.load(columns.fetch("objects", '{}')),
      "timelines" => JSON.load(columns.fetch("timelines", '[]')),
      "token" => columns.fetch('token', '')
    }

    new(to_load)
  end

  def set_token
    self.token = [Time.now.utc.tv_sec, key].join('_')
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

