require 'active_support/concern'
require 'active_model'

class Chronologic::Client

  module Event
    extend ActiveSupport::Concern

    included do
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

      # HAX spec this
      # def from(attrs)
      #   new.tap do |event|
      #     event.new_record = false
      #     attrs.each { |name, value| event.send("#{name}=", value) }
      #   end
      # end
    end

    module InstanceMethods

      def initialize
        @attributes = {}
        # self.new_record = true
        super
      end

      def save
        new_record? ? publish : update
      end

      def new_record?
        new_record
      end

      def publish
        # SLIME
      end

    end

  end

end
