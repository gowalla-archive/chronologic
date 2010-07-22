require 'cassandra'

module Chronologic
  class Connection
    def clear!
      Chronologic.cassandra.clear_keyspace!
    end
    
    def object(key, info)
      Chronologic.cassandra.insert(:Object, key.to_s, stringify_keys(info))
      nil
    end

    def get_object(key)
      symbolize_keys(Chronologic.cassandra.get(:Object, key.to_s))
    end

    def remove_object(key)
      Chronologic.cassandra.remove(:Object, key.to_s)
      # TODO: remove any events that use this object
      nil
    end

    def subscribe(subscriber, subscription)
      Chronologic.cassandra.batch do
        Chronologic.cassandra.insert(:Subscription, "#{subscriber}:subscriptions", {subscription.to_s => ''})
        Chronologic.cassandra.insert(:Subscription, "#{subscription}:subscribers", {subscriber.to_s => ''})
      end
      nil
    end
  
    def subscribers(subscriptions)
      subscriptions = [subscriptions] unless subscriptions.is_a?(Array)
      subscriptions = subscriptions.map{ |k| "#{k}:subscribers" }
      Chronologic.cassandra.multi_get(:Subscription, subscriptions).map{ |k,v| v.keys }.flatten
    end

    # TODO
    def unsubscribe(subscriber, subscription)
      #Chronologic.cassandra.batch do
      #  Chronologic.cassandra.remove(:Subscription, subject.to_s, ...?)
      #  Chronologic.cassandra.remove(:Subscription, subject.to_s, ...?)
      #end
      nil
    end
    
    def event(options={})
      Chronologic.cassandra.batch do
        event_key = (options[:key] || SimpleUUID::UUID.new.to_guid).to_s
        info = options[:info] || {}
        subscribers = options[:subscribers] || []
        timelines = options[:timelines] || []
        objects = options[:objects] || {}
        events = options[:events] || []
        event_data = {
          'info' => stringify_keys(info),
          'subscribers' => stringify_keys(subscribers),
          'timelines' => stringify_keys(timelines),
          'objects' => stringify_keys(objects),
          'events' => stringify_keys(events),
        }
        all_timelines = ([:_global] + timelines + subscribers(subscribers)).flatten
        Chronologic.cassandra.insert(:Event, event_key, event_data)
        all_timelines.each do |timeline_key|
          Chronologic.cassandra.insert(:Timeline, timeline_key.to_s, { SimpleUUID::UUID.new => event_key })
        end
        # TODO: store links to timelines for the objects/events, so that we can delete the events if the objects are deleted
      end
      nil
    end

    def remove_event(key)
      Chronologic.cassandra.remove(:Event, key.to_s)
      # TODO: remove event reference from all applicable timelines
      nil
    end

    def timeline(timeline_key)
      keys = Chronologic.cassandra.get(:Timeline, timeline_key.to_s, :reversed => true).map(&:last)
      rows = Chronologic.cassandra.multi_get(:Event, keys)
      rows.map do |k, v|
        result = v['info']
        (v['objects'] || []).each do |object_name, object_key|
          result[object_name] = regular_hash(Chronologic.cassandra.get(:Object, object_key)) # TODO: multi-get
        end
        regular_hash(result)
      end
    end
    
    def global_timeline
      timeline(:_global)
    end

    private
    
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
