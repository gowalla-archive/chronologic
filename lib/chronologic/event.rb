require "hashie/dash"
require "time"

class Chronologic::Event < Hashie::Dash

  property :key
  property :timestamp
  property :data, :default => {}
  property :objects, :default => {}
  property :timelines, :default => []
  property :subevents, :default => []

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
    to_load = {
      "data" => JSON.load(columns["data"]), 
      "objects" => JSON.load(columns["objects"]), 
      "timelines" => JSON.load(columns["timelines"]), 
      "timestamp" => Time.parse(columns["timestamp"])
    }
    new(to_load)
  end

end

