require "cassandra"

class Chronologic::Schema
  attr_accessor :connection

  def create_object(key, attrs)
    uuid = new_guid
    # FIXME: don't like this use of column->value
    connection.insert(:Object, key, uuid => attrs.to_json)
    uuid
  end

  def object_for(object_key)
    case object_key
    when String
      JSON.load(connection.get(:Object, object_key).values.first)
    when Array
      connection.multi_get(:Object, object_key).values.map { |hsh| JSON.load(hsh.values.first) }
    end
  end

  def create_subscription(timeline, subscriber)
    uuid = new_guid
    connection.insert(
      :Subscription, 
      "#{timeline}:subscriptions", 
      # FIXME: don't like this use of column->value
      {uuid => subscriber}
    )
    connection.insert(
      :Subscription, 
      "#{subscriber}:timelines", 
      # FIXME: don't like this use of column->value
      {uuid => timeline}
    )
    # TODO: event copying (?)
    uuid
  end

  def subscribers_for(timeline)
    connection.get(:Subscription, "#{timeline}:subscriptions").values
  end

  def subscriptions_for(subscriber)
    connection.get(:Subscription, "#{subscriber}:timelines").values
  end

  def create_event(event_key, data)
    connection.insert(:Event, event_key, data)
  end

  def event_for(event_key)
    case event_key
    when Array
      connection.multi_get(:Event, event_key).values
    when String
      connection.get(:Event, event_key)
    end
  end

  def create_timeline_event(timeline, event_key)
    connection.insert(:Timeline, timeline, {new_guid => event_key})
  end

  def timeline_events_for(timeline)
    connection.get(:Timeline, timeline).values
  end

  def new_guid
    SimpleUUID::UUID.new.to_guid
  end

end

