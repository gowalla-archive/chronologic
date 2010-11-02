require "hashie/dash"

class Chronologic::Event < Hashie::Dash

  property :key
  property :timestamp
  property :data
  property :objects
  property :timelines
  property :subevents

  def to_columns
    raise NestedDataError.new if data_is_nested?
    {
      "timestamp" => timestamp.utc.iso8601,
      "data" => data,
      "objects" => objects,
      "timelines" => timelines
    }
  end

  def data_is_nested?
    data.values.any? { |v| v.is_a?(Hash) || v.is_a?(Array) || v.is_a?(Set) }
  end

end

