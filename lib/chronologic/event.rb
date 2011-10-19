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

  # Implement in both
  def empty?
    data.empty?
  end

end

module Chronologic::Event; end

module Chronologic::Event::State
  extend ActiveSupport::Concern

  included do
    # HAX figure out how to get token out of the common state
    attr_accessor :key, :token, :data, :objects, :timelines, :subevents
  end

  def initialize
    @key       = ''
    @token     = ''
    @data      = {}
    @objects   = {}
    @timelines = []
    @subevents = []
  end

  module ClassMethods

    def from_attributes(hsh)
      attrs = hsh.with_indifferent_access # HAX?
      new.tap do |event|
        event.key       = attrs.fetch(:key, '')
        event.token     = attrs.fetch(:token, '')
        event.data      = attrs.fetch(:data, {})
        event.objects   = attrs.fetch(:objects, {})
        event.timelines = attrs.fetch(:timelines, [])
        event.subevents = attrs.fetch(:subevents, [])
      end
    end

  end

end

module Chronologic::Event::Behavior

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

  def ==(other)
    key == other.key &&
      token == other.token &&
      data == other.data &&
      objects == other.objects &&
      timelines == other.timelines &&
      subevents == other.subevents
  end

end

