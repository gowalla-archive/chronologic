# Subscribe to a timeline, publish an event, verify fanout to other timelines

require 'boilerplate'
connection = Chronologic::Client::Connection.new('http://localhost:7979')

connection.subscribe("tech", "home")

event = Chronologic::Event.new
event.key = "story_1"
event.timestamp = Time.now.utc
event.data = {
  "headline" => "First ever post in Chronologic!",
  "lede" => "A monumental occasion for housecats everywhere.",
  "body" => "There is currently a cat perched on my arm. This is normal, carry on!"
}
event.timelines = ["tech"]

connection.publish(event)

feed = connection.timeline("home")

puts "Home has #{feed['count']} events."
pp feed['items'].first

