#require 'eventmachine'
#require 'em-http-request'
#require 'yajl'
#
#EventMachine.run do
#
#  request = EventMachine::HttpRequest.new('http://127.0.0.1:9393/timelines/')
#  body = {'status' => 'Hello Twitter from em-http-request with OAuth'}
#  head = {"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json"}
#  http = request.get(:body => body, :head => head)
#
#  http.callback do
#    data = Yajl::Parser.parse(http.response)
#    puts data.inspect # "Response: #{http.response} (Code: #{http.response_header.status})"
#    EventMachine.stop
#  end
#
#end


begin
  require 'uri'
  require 'net/http/persistent'
  require 'yajl/http_stream'
rescue LoadError
  require 'uri'
  require 'rubygems'
  require 'net/http/persistent'
  require 'yajl/http_stream'
end

module Chronologic
  class Client
    def initialize
      @http = Net::HTTP::Persistent.new
      @base_url = URI.parse('http://localhost:4567/')
    end
    
    def clear!
      request = Net::HTTP::Delete.new(@base_url.path)
      response = @http.request(@base_url, request)
    end

    def object(object_key, data)
      url = @base_url + "objects/#{object_key}"
      request = Net::HTTP::Put.new(url.path)
      request.set_form_data(data)
      response = @http.request(url, request)
    end

    def remove_object(object_key)
      url = @base_url + "objects/#{object_key}"
      request = Net::HTTP::Delete.new(url.path)
      response = @http.request(url, request)
    end

    def subscribe(subscriber, subscription)
      url = @base_url + "subscriptions/#{subscriber}/#{subscription}"
      request = Net::HTTP::Put.new(url.path)
      response = @http.request(url, request)
    end
  
    def unsubscribe(subscriber, subscription)
      url = @base_url + "subscriptions/#{subscriber}/#{subscription}"
      request = Net::HTTP::Delete.new(url.path)
      response = @http.request(url, request)
    end
    
    def event(event_key, options={})
      url = @base_url + "events/#{event_key}"
      data = []
      (options[:events] || []).each { |v| data << ["events[]", v] }
      (options[:timelines] || []).each { |v| data << ["timelines[]", v] }
      (options[:subscribers] || []).each { |v| data << ["subscribers[]", v] }
      (options[:objects] || {}).each { |k,v| data << ["objects[#{k}]", v] }
      (options[:data] || {}).each { |k,v| data << ["data[#{k}]", v] }
      data << ["created_at", options[:created_at].utc.iso8601] if options[:created_at]

      request = Net::HTTP::Put.new(url.path)
      request.set_form_data(data)
      response = @http.request(url, request)
    end

    def remove_event(event_key)
      url = @base_url + "events/#{event_key}"
      request = Net::HTTP::Delete.new(url.path)
      response = @http.request(url, request)
    end

    def timeline(timeline_key, options={})
      url = @base_url + "timelines/#{timeline_key}"
      timeline = Yajl::HttpStream.get(url)
      timeline['events'] = timeline['events'].map do |event|
        event = symbolize_keys(event)
        event[:created_at] = Time.parse(event[:created_at])
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
        v.inject([]) do |c, val|
          c << "#{urlencode(k.to_s)}=#{urlencode(val.to_s)}"
        end.join('&')
      end.join('&')
    end
  end
end
