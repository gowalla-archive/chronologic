module ChronologicHelpers

  def simple_event(kind=:service)
    case kind
    when :service
      Chronologic::Service::Event.new.tap do |event|
        event.key = "checkin_1"
        event.data = {"type" => "checkin", "message" => "I'm here!"}
        event.objects = {"user" => "user_1", "spot" => "spot_1"}
        event.timelines = ["user_1", "spot_1"]
      end
    when :client
      Chronologic::Event.new.tap do |event|
        event.key = "checkin_1"
        event.data = {"type" => "checkin", "message" => "I'm here!"}
        event.objects = {"user" => "user_1", "spot" => "spot_1"}
        event.timelines = ["user_1", "spot_1"]
      end
    else
      raise ArgumentError.new("Unknown event: #{kind}")
    end
  end

  def nested_event
    Chronologic::Service::Event.new.tap do |event|
      event.key = "comment_1"
      event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1"}
      event.objects = {"user" => "user_2"}
      event.timelines = ["checkin_1"]
    end
  end

  def populate_timeline
    jp = {"name" => "Juan Pelota's"}
    protocol.record("spot_1", jp)

    events = []
    %w{sco jc am pb mt rm ak ad rs bf}.each_with_index do |u, i|
      record = {"name" => u}
      key = "user_#{i}"
      protocol.record(key, record)

      protocol.subscribe("user_1_home", "user_#{i}")

      event = simple_event
      event.key = "checkin_#{i}"
      event.objects["user"] = key
      event.timelines = [key, "spot_1"]

      events << event
      protocol.publish(event)
    end

    return events
  end

  # Cassandra#truncate isn't reliable against cassandra-0.7.4, but
  # this gets the job done. It's a hack, so look for a better way to do this
  # every now and then
  def clean_up_keyspace!(conn)
    conn.schema.cf_defs.each do |cf|
      conn.send(:each_key, cf.name) do |k|
        conn.remove(cf.name, k)
      end
    end
  end

end

