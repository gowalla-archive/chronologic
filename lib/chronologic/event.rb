require 'active_support/core_ext/hash'
require 'active_support/concern'
require "time"

module Chronologic::Event::State
  extend ActiveSupport::Concern

  included do
    attr_accessor :key, :data, :objects, :timelines, :subevents
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
      attrs = hsh.with_indifferent_access
      new.tap do |event|
        event.key       = attrs.fetch(:key, '')
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
    # @children ||= subevents.map { |s| self.class.from_attributes(s) }
    @children ||= subevents.map do |s|
      if s.is_a?(self.class)
        s
      else
        self.class.from_attributes(s)
      end
    end
  end

  def empty?
    data.empty?
  end

  def ==(other)
    other.is_a?(self.class) &&
      key == other.key &&
      data == other.data &&
      objects == other.objects &&
      timelines == other.timelines &&
      subevents == other.subevents
  end

end

