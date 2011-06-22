require 'active_support/concern'
require 'active_support/inflector'
require 'active_model'

class Chronologic::Client

  module Event
    extend ActiveSupport::Concern

    included do
      cattr_accessor :client

      # ??? Protect this?
      attr_accessor :new_record

      attr_accessor :objects
      attr_accessor :events

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
        }, __FILE__, __LINE__
      end

      def events(name)
        self.class_eval %Q{
          def #{name}
            events.values
          end

          def add_#{name.to_s.singularize}(obj)
            events[obj.to_cl_key] = obj
          end

          def remove_#{name.to_s.singularize}(obj)
            events.delete(obj.to_cl_key)
          end
        }, __FILE__, __LINE__

      end

      def fetch(event_key)
        new.from(client.fetch(event_key))
      end
    end

    module InstanceMethods

      def initialize
        @attributes = {}
        @new_record = true
        @objects = Hash.new { |h, k| h[k] = {} }
        @events = Hash.new { |h, k| h[k] = {} }
        super
      end

      def save
        new_record? ? publish : update
      end

      def new_record?
        @new_record
      end

      def publish
        client.publish # SLIME
      end

      def update
        client.update # SLIME
      end

      def destroy
        raise %q{Won't destroy a new record} if new_record?
        client.unpublish # SLIME
      end

      def from(attrs)
        load_attributes(attrs.fetch('data', []))
        load_objects(attrs.fetch('objects', {}))
        load_events(attrs.fetch('subevents', {}))
        clear_new_record

        self
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

      def clear_new_record
        @new_record = false
      end

    end

  end

end
