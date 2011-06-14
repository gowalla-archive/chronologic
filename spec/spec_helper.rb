require 'chronologic'

RSpec.configure do |config|
  
  def simple_event
    Chronologic::Event.new.tap do |event|
      event.key = "checkin_1"
      event.timestamp = Time.now.utc
      event.data = {"type" => "checkin", "message" => "I'm here!"}
      event.objects = {"user" => "user_1", "spot" => "spot_1"}
      event.timelines = ["user_1", "spot_1"]
    end
  end

  def nested_event
    Chronologic::Event.new.tap do |event|
      event.key = "comment_1"
      event.timestamp = Time.now.utc
      event.data = {"type" => "comment", "message" => "Me too!", "parent" => "checkin_1"}
      event.objects = {"user" => "user_2", "checkin" => "checkin_1"}
      event.timelines = ["checkin_1"]
    end
  end

end
