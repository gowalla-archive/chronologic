require "active_support/concern"

module Chronologic::Record
  extend ActiveSupport::Concern

  included do

    def record(object_key, data)
      client.record(object_key, data)
    end

    def unrecord(object_key)
      client.unrecord(object_key)
    end

    def client
      Chronologic::Client.instance
    end

  end

end
