require 'active_support/concern'
require 'active_support/core_ext/class'
require 'active_support/inflector'
require 'active_model'

module Chronologic::Client::Event

  extend ActiveSupport::Concern

  included do
    # XXX Protect this?
    attr_accessor :new_record
    attr_accessor :objects, :events
    attr_accessor :cl_key, :timestamp

    attr_reader :timelines
    attr_reader :cl_url
  end

  module ClassMethods
    def attribute(name)
      self.class_eval <<-RUBY, __FILE__, __LINE__
        attr_accessor :attributes

        def #{name}
          @attributes[:#{name}]
        end

        def #{name}=(val)
          @dirty_attributes = true
          @attributes[:#{name}] = val
        end
      RUBY
    end

    def objects(name, klass)
      self.class_eval <<-RUBY, __FILE__, __LINE__
        # SLOW this potentially converts hashes to the klass every time.
        # Could memoize this sometime in the future.
        def #{name}
          objects.
            fetch('#{name}', {}).
            values.map { |obj|
              obj.is_a?(#{klass}) ? obj : #{klass}.new.from_cl(obj)
            }.sort
        end

        def add_#{name.to_s.singularize}(obj)
          @dirty_objects = true
          objects['#{name}'][obj.to_cl_key] = obj
        end

        def remove_#{name.to_s.singularize}(obj)
          @dirty_objects = true
          objects['#{name}'].delete(obj.to_cl_key)
        end
      RUBY
    end

    def events(name, klass)
      self.class_eval <<-RUBY, __FILE__, __LINE__
        def #{name}
          casted_events
        end

        def add_#{name.to_s.singularize}(obj)
          @dirty_events = true
          events[obj.to_cl_key] = obj
        end

        def remove_#{name.to_s.singularize}(obj)
          @dirty_events = true
          events.delete(obj.to_cl_key)
        end

        def event_class
          #{klass}
        end
      RUBY
    end

    def fetch(event_url)
      new.from(connection.fetch(event_url))
    end

    # HAX
    def connection
      Chronologic::Client::Connection.instance
    end
  end

  module InstanceMethods

    def initialize
      @attributes = {}
      @new_record = true
      @dirty_attributes = false
      @dirty_timelines = false
      @dirty_objects = false
      @dirty_events = false # XXX merge all these dirty flags
      @objects = Hash.new { |h, k| h[k] = {} }
      @events = Hash.new { |h, k| h[k] = {} }
      @timelines = []
      super
    end

    def connection
      Chronologic::Client::Connection.instance
    end

    def parent
      @attributes['parent']
    end

    def parent=(parent_key)
      @attributes['parent'] = parent_key
      add_timeline(parent_key)
    end

    def parent_key
      @attributes['parent']
    end

    def new_record?
      @new_record
    end

    def add_timeline(timeline)
      @dirty_timelines = true
      @timelines << timeline
    end

    def remove_timeline(timeline)
      @dirty_timelines = true
      @timelines.delete(timeline)
    end

    def dirty_timelines?
      @dirty_timelines
    end

    def cl_changed?
      @dirty_attributes || @dirty_objects || @dirty_timelines || @dirty_events
    end

    def cl_timestamp
      timestamp
    end

    def cl_attributes
      @attributes
    end

    def cl_objects
      objects.inject({}) { |hsh, (key, objs)| hsh.update(key => objs.keys) }
    end

    def cl_timelines
      timelines
    end

    def cl_subevents
      events.keys
    end

    def casted_events
      events.values.map { |obj|
        obj.is_a?(event_class) ? obj : event_class.new.from_cl(obj)
      }.sort
    end

    def save
      return false unless cl_changed?
      save_subevents

      result = new_record? ? publish : update

      @cl_url           = result
      @new_record       = false
      @dirty_attributes = false
      @dirty_objects    = false
      @dirty_timelines  = false
      @dirty_events     = false

      result
    end

    def save_subevents
      casted_events.each do |event|
        event.parent = cl_key
        event.save
      end
    end

    def publish
      event = Chronologic::Event.new(
        :key       => cl_key,
        :timestamp => cl_timestamp,
        :data      => cl_attributes,
        :objects   => cl_objects,
        :timelines => cl_timelines
      )
      connection.publish(event)
    end

    def update
      # How to prevent timestamp changes (?)

      event = Chronologic::Event.new(
        :key => cl_key,
        :timestamp => cl_timestamp,
        :data => cl_attributes,
        :objects => cl_objects,
        :timelines => cl_timelines
      )
      connection.update(event, dirty_timelines?)
    end

    def destroy
      raise %q{Won't destroy a new record} if new_record?
      connection.unpublish(cl_key)
    end

    def from(attrs)
      load_key(attrs.fetch('key', ''))
      load_timestamp(attrs.fetch('timestamp', 'blurg'))
      load_attributes(attrs.fetch('data', {}))
      load_objects(attrs.fetch('objects', {}))
      load_timelines(attrs.fetch('timelines', []))
      load_events(attrs.fetch('subevents', {}))
      clear_new_record_flag

      self
    end

    def load_key(key)
      self.cl_key = key
    end

    def load_timestamp(timestamp)
      self.timestamp = timestamp
    end

    def load_attributes(attrs)
      attrs.each { |name, value| send("#{name}=", value) }
    end

    def load_objects(objs)
      self.objects = objs
    end

    def load_timelines(timelines)
      @timelines = timelines
    end

    def load_events(objs)
      self.events = objs.inject({}) { |events, obj| events.update(obj.key => obj) }
    end

    def clear_new_record_flag
      @new_record = false
    end

    def ==(other)
      return false unless other.is_a?(self.class)

      cl_key == other.cl_key &&
        cl_timestamp.to_s == other.cl_timestamp.to_s &&
        cl_attributes == other.cl_attributes &&
        cl_objects == other.cl_objects &&
        cl_subevents == other.cl_subevents
    end
  end
end
