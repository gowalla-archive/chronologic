require 'active_support/concern'
require 'active_support/core_ext/class'
require 'active_support/inflector'
require 'active_model'

module Chronologic::Client::Event

  extend ActiveSupport::Concern

  included do
    cattr_accessor :client

    # ??? Protect this?
    attr_accessor :new_record

    attr_accessor :objects
    attr_accessor :events

    attr_accessor :cl_key
    attr_accessor :timelines
    attr_accessor :timestamp

    include ActiveModel::Dirty
  end

  module ClassMethods
    def attribute(name)
      self.class_eval %Q{
        define_attribute_methods [:#{name}]

        def #{name}
          @attributes[:#{name}]
        end

        def #{name}=(val)
        #{name}_will_change! unless val == @attributes[:#{name}]
          @attributes[:#{name}] = val
        end

        def cl_attributes
          @attributes
        end
      }, __FILE__, __LINE__
    end

    def objects(name, klass)
      self.class_eval %Q{
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
          objects['#{name}'][obj.to_cl_key] = obj
        end

        def remove_#{name.to_s.singularize}(obj)
          objects['#{name}'].delete(obj.to_cl_key)
        end

        def cl_objects
          objects.inject({}) { |hsh, (key, objs)| hsh.update(key => objs.keys) }
        end
      }, __FILE__, __LINE__
    end

    def events(name, klass)
      self.class_eval %Q{
        def #{name}
          events.values.map { |obj|
            obj.is_a?(#{klass}) ? obj : #{klass}.new.from_cl(obj)
          }.sort
        end

        def add_#{name.to_s.singularize}(obj)
          events[obj.to_cl_key] = obj
        end

        def remove_#{name.to_s.singularize}(obj)
          events.delete(obj.to_cl_key)
        end

        def cl_subevents
          events.keys
        end
      }, __FILE__, __LINE__

    end

    def fetch(event_url)
      new.from(client.fetch(event_url))
    end
  end

  module InstanceMethods

    def initialize
      @attributes = {}
      @new_record = true
      @objects = Hash.new { |h, k| h[k] = {} }
      @events = Hash.new { |h, k| h[k] = {} }
      @timelines = []
      super
    end

    def cl_timestamp
      timestamp
    end

    def cl_timelines
      timelines
    end

    def save
      new_record? ? publish : update
    end

    def new_record?
      @new_record
    end

    def publish
      event = Chronologic::Event.new(
        :key       => cl_key,
        :timestamp => cl_timestamp,
        :data      => cl_attributes,
        :objects   => cl_objects,
        :timelines => cl_timelines,
        :subevents => cl_subevents
      )
      client.publish(event)
    end

    def update
      client.update # SLIME
    end

    def destroy
      raise %q{Won't destroy a new record} if new_record?
      client.unpublish # SLIME
    end

    def from(attrs)
      load_key(attrs.fetch('key', ''))
      load_timestamp(attrs.fetch('timestamp', 'blurg'))
      load_attributes(attrs.fetch('data', {}))
      load_objects(attrs.fetch('objects', {}))
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

    def load_events(objs)
      self.events = objs
    end

    def clear_new_record_flag
      @new_record = false
    end

    def ==(other)
      return false unless other.is_a?(self.class)

      cl_key == other.cl_key &&
        cl_timestamp == other.cl_timestamp &&
        cl_attributes == other.cl_attributes &&
        cl_objects == other.cl_objects &&
        cl_subevents == other.cl_subevents
    end
  end
end
