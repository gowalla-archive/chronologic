require "chronologic"

cl = Chronologic::Client.new("http://localhost:7979")

# Create ten events, push to ten timelines, unpublish them, and publish a new
# event in the middle of the sequence

user = "outing_user_0"
users = 10.times.map { |i| "outing_user_#{i + 1}" }
# users.each { |u| cl.subscribe("outing_user_#{u}_feed", user) }
users.each { |u| cl.subscribe(user, "#{u}_feed") }

events = 10.times.map do |i|
  event = Chronologic::Event.new.tap do |e|
    e.key = "checkin_#{i}"
    e.timestamp = Time.now + i
    e.data = {"message" => "This is checkin #{i}"}
    e.timelines = [user]
  end
  [event, cl.publish(event).split('/').last]
end

# Now we're going to create an outing from event[4] and event[5].
cl.unpublish(events[4].first.key)
cl.unpublish(events[5].first.key)

outing = Chronologic::Event.new.tap do |e|
  e.key = "outing_1"
  e.timestamp = events[4].first.timestamp 
  e.data = {"type" => "flight", "note" => "This should appear after checkin 3"}
  e.timelines = [user]
end
cl.publish(outing)


events[4].first.timelines = ["outing_1"]
events[5].first.timelines = ["outing_1"]
cl.publish(events[4].first)
cl.publish(events[5].first)

cl.timeline(user)["items"].each do |event|
  puts "#{event.key} - #{event['data'].inspect} - #{event.timestamp}"
end

puts "---"

cl.timeline("outing_user_1_feed")["items"].each do |event|
  puts "#{event.key} - #{event['data'].inspect} - #{event.timestamp}"
end
