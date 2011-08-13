# Publish an event, publish a subevent, fetch both in one operation

require 'boilerplate'
connection = Chronologic::Client::Connection.new('http://localhost:9292')

event = Chronologic::Event.new
event.key = "story_1"
event.timestamp = Time.now
event.data = {
  "headline" => "First ever post in Chronologic!",
  "lede" => "A monumental occasion for housecats everywhere.",
  "body" => "There is currently a cat perched on my arm. This is normal, carry on!"
}
event.timelines = ["home"]

connection.publish(event)

subevent = Chronologic::Event.new
subevent.key = "comment_1"
subevent.timestamp = Time.now
subevent.data = {
  "message" => "LOL cats!"
}
subevent.parent = "story_1"
subevent.timelines = ["story_1"]

connection.publish(subevent)

feed = connection.timeline("home")

pp feed['items'].first

