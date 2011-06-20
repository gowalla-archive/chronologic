require 'active_support/concern'
require 'active_model'

class Chronologic::Client

  module Event
    extend ActiveSupport::Concern

    included do
      cattr_accessor :client

      # ??? Protect this?
      attr_accessor :new_record

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

      def fetch(event_key)
        new.from(client.fetch(event_key))
      end
    end

    module InstanceMethods

      def initialize
        @attributes = {}
        @new_record = true
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
        attrs.each { |name, value| send("#{name}=", value) }
        @new_record = false
        self
      end

    end

  end

end
