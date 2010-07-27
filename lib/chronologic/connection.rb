begin
  require 'cassandra'
rescue LoadError
  require 'rubygems'
  require 'cassandra'
end

module Chronologic
  class Connection
    def cassandra=(cassandra)
      @cassandra = cassandra
    end

    def cassandra
      return @cassandra if @cassandra
      @cassandra = Cassandra.new('Chronologic')
      @cassandra
    end

    def clear!
      cassandra.clear_keyspace!
    end
    
    def object(object_key, data)
      cassandra.insert(:Object, object_key.to_s, stringify_keys(data))
      nil
    end

    def get_object(object_key)
      symbolize_keys(cassandra.get(:Object, object_key.to_s))
    end

    def remove_object(object_key)
      cassandra.batch do
        cassandra.remove(:Object, object_key.to_s)
        event_keys("_object:#{object_key}").each{ |event_key| remove_event(event_key) }
      end
      nil
    end

    def subscribe(timeline_key, subscription_key)
      cassandra.batch do
        cassandra.insert(:Subscription, "#{timeline_key}:subscriptions", {subscription_key.to_s => ''})
        cassandra.insert(:Subscription, "#{subscription_key}:timelines", {timeline_key.to_s => ''})
      end
      nil
    end

    def unsubscribe(timeline_key, subscription_key)
      cassandra.batch do
        cassandra.remove(:Subscription, "#{timeline_key}:subscriptions", subscription_key.to_s)
        cassandra.remove(:Subscription, "#{subscription_key}:timelines", timeline_key.to_s)
        event_keys("_subscriber:#{subscription_key}").each{ |event_key| remove_timeline_event(timeline_key, event_key) }
      end
      nil
    end
    
    def event(key, options={})
      event_key = key.to_s
      data = options[:data] || {}
      subscribers = options[:subscribers] || []
      timelines = options[:timelines] || []
      objects = options[:objects] || {}
      events = options[:events] || []
      event_data = {
        'data' => stringify_keys(data),
        'subscribers' => stringify_keys(subscribers),
        'timelines' => stringify_keys(timelines),
        'objects' => stringify_keys(objects),
        'events' => stringify_keys(events),
      }
      cassandra.batch do
        cassandra.insert(:Event, event_key, event_data)
        timeline_keys(event_data).each do |timeline_key|
          cassandra.insert(:Timeline, timeline_key.to_s, { SimpleUUID::UUID.new => event_key })
        end
      end
      nil
    end

    def remove_event(event_key)
      cassandra.batch do
        event_data = cassandra.get(:Event, event_key)
        timeline_keys(event_data).each do |timeline_key|
          remove_timeline_event(timeline_key, event_key)
        end
        event_keys("_event:#{event_key}").each{ |key| remove_event(key) }
        cassandra.remove(:Event, event_key.to_s)
      end
      nil
    end

    def timeline(timeline_key)
      keys = event_keys(timeline_key)
      rows = cassandra.multi_get(:Event, keys)
      rows.map do |k, v|
        result = v['data']
        (v['objects'] || []).each do |object_name, object_key|
          # TODO: multi-get
          result[object_name] = regular_hash(cassandra.get(:Object, object_key))
        end
        regular_hash(result)
      end
    end

    private
    
    def timeline_keys(event_data)
      timelines = event_data['timelines']
      timelines << :_global
      timelines << subscription_timelines(event_data['subscribers'])
      timelines << event_data['objects'].map{ |k| "_object:#{k}" }
      timelines << event_data['events'].map{ |k| "_event:#{k}" }
      timelines << event_data['subscribers'].map{ |k| "_subscriber:#{k}" }
      timelines
    end
    
    def remove_timeline_event(timeline_key, event_key)
      # TODO: this isn't right
      cassandra.remove(:Timeline, timeline_key.to_s, event_key.to_s)
    end
    
    def event_keys(timeline_key)
      cassandra.get(:Timeline, timeline_key.to_s, :reversed => true).map(&:last)
    end
    
    def subscription_timelines(subscription_keys)
      cassandra.multi_get(:Subscription, subscription_keys.map{ |k| "#{k}:timelines" }).map{ |k,v| v.keys }.flatten
    end
    
    def regular_hash(ordered_hash)
      ordered_hash.inject({}) do |h, (k, v)|
        h[k.to_sym] = v
        h
      end
    end

    def stringify_keys(hash)
      hash.inject({}) do |options, (key, value)|
        options[key.to_s] = value
        options
      end
    end

    def symbolize_keys(hash)
      hash.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = value
        options
      end
    end
  end
end
