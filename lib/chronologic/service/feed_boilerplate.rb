require 'active_support/concern'

module Chronologic::Service::FeedBoilerplate
  extend ActiveSupport::Concern

  included do
    attr_accessor :timeline_key, :per_page, :start, :subevents
    attr_accessor :next_page, :count
  end

  module ClassMethods

    def create(timeline_key, options={})
      fetch_subevents = options[:fetch_subevents]
      count = options[:per_page] || 20
      start = options[:page] || nil

      feed = new(timeline_key, count, start, fetch_subevents)
    end

  end

  module InstanceMethods
    def initialize(timeline_key, per_page=20, start=nil, subevents=false)
      self.timeline_key = timeline_key
      self.per_page = per_page
      self.start = start
      self.subevents = subevents
    end

    def set_count
      self.count = schema.timeline_count(timeline_key)
    end

    def set_next_page
      current = schema.timeline_events_for(
        timeline_key,
        :per_page => per_page + 1,
        :page => start
      )

      if current.length == (per_page + 1)
        self.next_page = current.keys.last
      else
        self.next_page = nil
      end
    end

    # Lookup events on the specified timeline(s) and return all the events
    # referenced by those timelines.
    #
    # timeline_keys - one or more String timeline_keys to fetch events from
    #
    # Returns a flat array of events
    def fetch_timelines(timeline_keys, per_page=20, page='')
      event_keys = schema.timeline_events_for(
        timeline_keys,
        :per_page => per_page,
        :page => page
      ).values.flatten

      schema.event_for(event_keys.uniq).
        map do |k, e|
        Chronologic::Service::Event.from_columns(e).tap do |event|
          event.key = k
        end
        end
    end

    # Fetch objects referenced by events and correctly populate the event objects
    #
    # events - an array of Chronologic::Service::Event objects to populate
    #
    # Returns a flat array of Chronologic::Service::Event objects with their object
    # references populated.
    def fetch_objects(events)
      object_keys = events.map { |e| e.objects.values }.flatten.uniq
      objects = schema.object_for(object_keys)
      events.map do |e|
        e.tap do
          e.objects.each do |type, keys|
            if keys.is_a?(Array)
              e.objects[type] = keys.map { |k| objects[k] }
            else
              e.objects[type] = objects[keys]
            end
          end
        end
      end
    end

    # Convert a flat array of Chronologic::Service::Events into a properly hierarchical
    # timeline.
    #
    # events - an array of Chronologic::Service::Event objects, each possibly referencing
    # other events
    #
    # Returns a flat array of Chronologic::Service::Event objects with their subevent
    # references correctly populated.
    def reify_timeline(events)
      event_index = events.inject({}) { |idx, e| idx.update(e.key => e) }
      timeline_index = events.inject([]) do |timeline, e|
        if e.subevent? && event_index.has_key?(e.parent)
          # AKK: something is weird about Hashie::Dash or Event in that if you 
          # push objects onto subevents, they are added to an object that is 
          # referenced by all instances of event. So, these dup'ing hijinks are 
          subevents = event_index[e.parent].subevents.dup
          subevents << e
          event_index[e.parent].subevents = subevents
        else
          timeline << e.key
        end
        timeline
      end
      timeline_index.map { |key| event_index[key] }
    end

    # Private: easier access to the Chronologic schema
    def schema
      Chronologic.schema
    end
  end

end
