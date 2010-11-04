require "active_support/concern"

module Chronologic::Subscriber
  extend ActiveSupport::Concern

  included do

    def timeline(timeline_key, fetch_subevents=false)
      client.timeline(timeline_key, fetch_subevents)
    end

    def subscribe(subscriber_key, timeline_key)
      client.subscribe(subscriber_key, timeline_key)
    end

    def unsubscribe(subscriber_key, timeline_key)
      client.unsubscribe(subscriber_key, timeline_key)
    end

    def client
      Chronologic::Client.instance
    end
    
  end

end
