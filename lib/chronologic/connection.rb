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
      cassandra.insert(:Object, object_key.to_s, stringify_keys(data.to_hash))
      nil
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
    
    def event(event_key, options={})
      options = symbolize_keys(options)
      event_data = {
        'data'        => stringify_keys(options[:data] || {}),
        'subscribers' => stringify_keys(options[:subscribers] || []),
        'timelines'   => stringify_keys(options[:timelines] || []),
        'objects'     => stringify_keys(options[:objects] || {}),
        'events'      => stringify_keys(options[:events] || []),
      }
      event_data['created_at'] = if options[:created_at]
        if options[:created_at].is_a?(Time)
          options[:created_at].to_i.to_s
        elsif options[:created_at].is_a?(String)
          Time.parse(options[:created_at]).to_i.to_s
        end
      else
        Time.now.utc.to_i.to_s
      end
      cassandra.batch do
        cassandra.insert(:Event, event_key.to_s, event_data)
        prefixed_event_key = event_data['created_at'] + ":" + event_key.to_s
        timeline_keys(event_data).each do |timeline_key|
          cassandra.insert(:Timeline, timeline_key, { prefixed_event_key => "" })
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

    # TODO: multi-get the objects, and only fetch events if there are any
    def timeline(timeline_key = :_global, options={}, include_subevents = true)
      timeline_key = :_global if timeline_key.nil?
      event_keys = event_keys(timeline_key, options)
      events = cassandra.multi_get(:Event, event_keys).map do |key, info|
        event = info['data']
        event[:created_at] = Time.at(info['created_at'].keys.first.to_i)
        (info['objects'] || []).each do |object_name, object_key|
          # TODO: multi-get
          event[object_name] = regular_hash(cassandra.get(:Object, object_key))
        end
        if include_subevents
          timeline = timeline("_event:#{key}", options, false)
          event[:events] = timeline[:events] if timeline[:events].size > 0
        end
        regular_hash(event)
      end
      { :events => events }
    end

    private
    
    def timeline_keys(event_data)
      timelines = event_data['timelines'].keys
      timelines << '_global'
      timelines << subscription_timelines(event_data['subscribers'].keys)
      timelines << event_data['objects'].keys.map{ |k| "_object:#{k}" }
      timelines << event_data['events'].keys.map{ |k| "_event:#{k}" }
      timelines << event_data['subscribers'].keys.map{ |k| "_subscriber:#{k}" }
      timelines.flatten
    end

    def event_keys(timeline_key, options={})
      #options.merge!(:reversed => true)
      options = { :reversed => true }
      cassandra.get(:Timeline, timeline_key.to_s, options).map{ |k, v| k.split(':')[1] }
    end
    
    def remove_timeline_event(timeline_key, event_key)
      # TODO: this isn't right
      cassandra.remove(:Timeline, timeline_key.to_s, event_key.to_s)
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
