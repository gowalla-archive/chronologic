require 'active_support/concern'
require 'active_support/core_ext/hash'

class Chronologic::Service::Event
  attr_accessor :key, :token, :data, :objects, :timelines, :subevents

  def initialize
    @data      = {}
    @objects   = {}
    @timelines = []
    @subevents = []
  end

  def self.from_attributes(hsh)
    attrs = hsh.with_indifferent_access # HAX?
    new.tap do |event|
      event.key       = attrs[:key]
      event.token     = attrs[:token]
      event.data      = attrs.fetch(:data, {})
      event.objects   = attrs.fetch(:objects, {})
      event.timelines = attrs.fetch(:timelines, [])
      event.subevents = attrs.fetch(:subevents, [])
    end
  end

  def self.from_columns(columns)
    from_attributes(
      :data      => json_decode(columns["data"], {}),
      :objects   => json_decode(columns["objects"], {}),
      :timelines => json_decode(columns["timelines"], []),
      :token     => columns["token"]
    )
  end
  # Total HAX
  class <<self
    alias_method :load_from_columns, :from_columns
  end

  def to_columns
    {
      "token"     => token,
      "data"      => json_encode(data),
      "objects"   => json_encode(objects),
      "timelines" => json_encode(timelines)
    }
  end

  def to_client_encoding
    {
      "key" => key,
      "data" => data,
      "objects" => objects,
      "timelines" => timelines,
      "subevents" => subevents.map(&:to_client_encoding)
    }
  end

  def set_token(force_timestamp=false)
    timestamp = if force_timestamp
      force_timestamp
    else
      Time.now.utc.tv_sec
    end
    self.token = [timestamp, key].join('_')
  end

  def ==(other)
    key == other.key &&
      token == other.token &&
      data == other.data &&
      objects == other.objects &&
      timelines == other.timelines &&
      subevents == other.subevents
  end

  module EventBehavior

    def self.included(klass)
      klass.class_eval do
        delegate :json_encode, :json_decode, :to => klass
      end

      # TODO move these methods out to the module
      klass.instance_eval do
        def json_encode(obj)
          MultiJson.encode(obj)
        end

        def json_decode(str, default=nil)
          return default if str.nil?

          MultiJson.decode(str)
        end
      end
    end

    # TODO make parent a column
    def subevent?
      data.has_key?("parent")
    end

    def parent
      data["parent"]
    end

    def parent=(parent)
      data["parent"] = parent
    end

    # Public: converts the event's subevents to Chronologic::Event objects
    #
    # Returns an array of Chronologic::Service::Event objects.
    def children
      @children ||= subevents.map { |s| self.class.from_attributes(s) }
    end

    def empty?
      data.empty?
    end
  end
  include EventBehavior # HAX

end

