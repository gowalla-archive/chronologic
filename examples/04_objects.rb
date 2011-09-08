# Create some objects, publish an event, publish a subevent, fetch it all

require 'boilerplate'
connection = Chronologic::Client::Connection.new('http://localhost:7979')

connection.record("author_1", {"name" => "Adam"})
connection.record("author_2", {"name" => "Fred Derp"})

event = Chronologic::Event.new
event.key = "story_1"
event.timestamp = Time.now
event.data = {
  "headline" => "First ever post in Chronologic!",
  "lede" => "A monumental occasion for housecats everywhere.",
  "body" => "There is currently a cat perched on my arm. This is normal, carry on!"
}
event.objects = {"author" => ["author_1"]}
event.timelines = ["home"]

connection.publish(event)

subevent = Chronologic::Event.new
subevent.key = "comment_1"
subevent.timestamp = Time.now
subevent.data = {
  "message" => "LOL cats!"
}
subevent.parent = "story_1"
subevent.objects = {"author" => ["author_2"]}
subevent.timelines = ["story_1"]

connection.publish(subevent)

feed = connection.timeline("home")

pp feed['items'].first
