begin
  require 'uri'
  require 'yajl'
  require 'patron'
rescue LoadError
  require 'rubygems'
  require 'uri'
  require 'yajl'
  require 'patron'
end

module Chronologic
  class Client
    def initialize
      @http = Patron::Session.new
      @http.base_url = "http://127.0.0.1:4567"
      @http.headers['Accept'] = 'application/json'
      @http.headers['Content-type'] = 'application/x-www-form-urlencoded'
    end
    
    def clear!
      @http.delete("/")
    end

    def object(object_key, data)
      @http.put("/objects/#{object_key}", data)
    end

    def remove_object(object_key)
      @http.delete("/objects/#{object_key}")
    end

    def subscribe(subscriber, subscription)
      @http.put("/subscriptions/#{subscriber}/#{subscription}", "")
    end
  
    def unsubscribe(subscriber, subscription)
      @http.delete("/subscriptions/#{subscriber}/#{subscription}")
    end
    
    def event(options={})
      event_key = options.delete(:key) # default to UUID?
      data = []
      (options[:events] || []).each { |v| data << ["events[]", v] }
      (options[:timelines] || []).each { |v| data << ["timelines[]", v] }
      (options[:subscribers] || []).each { |v| data << ["subscribers[]", v] }
      (options[:objects] || {}).each { |k,v| data << ["objects[#{k}]", v] }
      (options[:data] || {}).each { |k,v| data << ["data[#{k}]", v] }
      data << ["created_at", options[:created_at].utc.iso8601] if options[:created_at]

      @http.put("/events/#{event_key}", form_data(data))
    end

    def remove_event(event_key)
      @http.delete("/events/#{event_key}")
    end

    def timeline(timeline_key, options={})
      response = @http.get("/timelines/#{timeline_key}?" + form_data(options))
      timeline = Yajl::Parser.parse(response.body)
      timeline['events'] = timeline['events'].map do |event|
        event = symbolize_keys(event)
        event[:created_at] = Time.parse(event[:created_at])
        if event[:events]
          event[:events] = event[:events].map do |subevent|
            subevent = symbolize_keys(subevent)
            subevent[:created_at] = Time.parse(subevent[:created_at])
            subevent
          end
        end
        event
      end
      symbolize_keys(timeline)
    end
    
    private

    def symbolize_keys(hash)
      hash.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = (value.is_a?(Hash) ? symbolize_keys(value) : value)
        options
      end
    end
    
    def form_data(params)
      params.map do |k, v|
        if v.respond_to?(:inject)
          v.inject([]) do |c, val|
            c << "#{urlencode(k.to_s)}=#{urlencode(val.to_s)}"
          end.join('&')
        else
          "#{urlencode(k.to_s)}=#{urlencode(v.to_s)}"
        end
      end.join('&')
    end
    
    def urlencode(str)
      str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end
  end
end
