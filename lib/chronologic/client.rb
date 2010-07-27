begin
  require 'httparty'
rescue LoadError
  require 'rubygems'
  require 'httparty'
end

module Chronologic
  class Client
    include HTTParty

    base_uri 'localhost:9393'
    default_options[:headers] = { "Accept" => "application/json", "Content-type" => "application/json" }
    
    def clear!
      self.class.delete('/')
    end

    def object(key, data)
      self.class.put("/objects/#{key}", data)
    end

    def get_object(key)
      self.class.get("/objects/#{key}")['object']
    end

    def remove_object(key)
      self.class.delete("/objects/#{key}")
    end

    def subscribe(subscriber, subscription)
      self.class.put("/subscriptions/#{subscriber}/#{subscription}")
    end
  
    def unsubscribe(subscriber, subscription)
      self.class.delete("/subscriptions/#{subscriber}/#{subscription}")
    end
    
    def event(key, options={})
      self.class.put("/events/#{key}", :body => options.to_json)
    end

    def remove_event(key)
      self.class.delete("/events/#{key}")
    end

    def timeline(timeline_key)
      self.class.get("/timelines/#{timeline_key}")['events']
    end
  end
end
