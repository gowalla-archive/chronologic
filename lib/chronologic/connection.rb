require 'cassandra'

module Chronologic
  class Connection
    def initialize(db)
      @db = db
    end

    def insert_object(key, info)
      @db.insert(:Objects, key.to_s, info)
    end

    def get_object(key)
      @db.get(:Objects, key.to_s)
    end

    def remove_object(key)
      @db.remove(:Objects, key.to_s)
      # TODO: remove any events that use this object
    end

    def insert_subscription(subject, target)
      @db.batch do
        @db.insert(:Subscriptions, subject.to_s, {'subscriptions' => {SimpleUUID::UUID.new => target.to_s}})
        @db.insert(:Subscriptions, target.to_s, {'subscribers' => {SimpleUUID::UUID.new => subject.to_s}})
      end
    end
  
    def get_subscribers(targets)
      targets = [targets] unless targets.is_a?(Array)
      @db.multi_get(:Subscriptions, targets.map(&:to_s), 'subscribers').values.map{ |h| h.values }.flatten
    end

    def remove_subscription(subject, target)
      #@db.batch do
      #  @db.remove(:Subscriptions, subject.to_s, ...?)
      #  @db.remove(:Subscriptions, subject.to_s, ...?)
      #end
    end
    
    def insert_event(event_info, options={})
      @db.batch do
        event_key = (options[:key] || SimpleUUID::UUID.new.to_guid).to_s
        @db.insert(:Events, event_key, event_info)
        timelines = (options[:timelines] + get_subscribers(options[:subscribers])).flatten
        timelines.each do |timeline_key|
          @db.insert(:Timelines, timeline_key.to_s, { 'events' => { SimpleUUID::UUID.new => event_key } })
        end
        # TODO: store links to timelines for the objects, so that we can delete the events if the objects are deleted
      end
    end

    def remove_event(key)
      @db.remove(:Events, key.to_s)
      # TODO
    end

    def get_timeline(timeline_key)
      keys = @db.get(:Timelines, timeline_key.to_s, 'events', :reversed => true).map(&:last)
      @db.multi_get(:Events, keys).values
      # TODO: include objects and sub-events
    end
  end
end
