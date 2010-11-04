require "active_support/concern"

module Chronologic::Publisher
  extend ActiveSupport::Concern

  included do

    def publish(event)
      # TODO: delegate to client?
      client.publish(event)
    end

    def unpublish(event_key, uuid)
      client.unpublish(event_key, uuid)
    end

    def client
      # FIXME: inject the client
      @client ||= Chronologic::Client.new('http://localhost:3000')
    end

  end

end

