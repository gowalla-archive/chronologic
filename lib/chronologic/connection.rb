begin
  require 'cassandra'
rescue LoadError
  require 'rubygems'
  require 'cassandra'
end

module Chronologic
  # TODO: rename to CassandraAdapter?
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
    
    def event(options={})
      event_key = options.delete(:key)
      created_at = options.delete(:created_at) || options.delete('created_at')
      options = symbolize_keys(options)
      event_data = {
        'data'        => stringify_keys(options[:data] || {}),
        'subscribers' => stringify_keys(options[:subscribers] || []),
        'timelines'   => stringify_keys(options[:timelines] || []),
        'objects'     => stringify_keys(options[:objects] || {}),
        'events'      => stringify_keys(options[:events] || []),
        'meta'        => {},
      }
      event_data['meta']['created_at'] = if created_at
        if created_at.is_a?(Time)
          created_at.to_i.to_s
        elsif created_at.is_a?(String)
          Time.parse(created_at).to_i.to_s
        end
      else
        Time.now.utc.to_i.to_s
      end
      cassandra.batch do
        cassandra.insert(:Event, event_key.to_s, event_data)
        prefixed_event_key = event_data['meta']['created_at'] + ":" + event_key.to_s
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

    # TODO: only fetch events if there are any
    def timeline(timeline_key = :_global, options={})
      include_subevents = options.delete(:include_subevents) || true
      timeline_key = :_global if timeline_key.nil?
      event_keys = event_keys(timeline_key, options)
      events = cassandra.multi_get(:Event, event_keys.map{ |k, v| k.split(':')[1] })
      object_keys = events.map{ |key, info| (info['objects'] || {}).values }.flatten.uniq
      objects = cassandra.multi_get(:Object, object_keys)
      events = events.map do |key, info|
        event = info['data']
        event[:created_at] = Time.at(info['meta']['created_at'].to_i)
        (info['objects'] || []).each do |object_name, object_key|
          event[object_name] = regular_hash(objects[object_key])
        end
        #if include_subevents
        #  timeline = timeline("_event:#{key}", :include_subevents => false)
        #  event[:events] = timeline[:events] if timeline[:events].size > 0
        #end
        regular_hash(event)
      end
      { :events => events,
        :total_count => events_count(timeline_key),
        :count => event_keys.size,
        :start => event_keys.first,
        :finish => event_keys.last }
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
    
    def events_count(timeline_key)
      cassandra.count_columns(:Timeline, timeline_key.to_s)
    end

    def event_keys(timeline_key, options={})
      options = symbolize_keys(options).merge(:reversed => true)
      cassandra.get(:Timeline, timeline_key.to_s, options).keys
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
