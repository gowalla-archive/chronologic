# Create some objects, create some subscriptions, publish some events, fetch

require 'boilerplate'
connection = Chronologic::Client::Connection.new('http://localhost:9292')

connection.record("user:ak", {"long_name" => "Adam Keys"})
connection.record("user:rs", {"long_name" => "Richard Schneeman"})
connection.record("user:mt", {"long_name" => "Mattt Thompson"})
connection.record("user:am", {"long_name" => "Adam Michaela"})

connection.record("spot:lsrc", {"name" => "Lone Star Ruby Conference"})

connection.subscribe("passport:ak", "friends:rs")
connection.subscribe("passport:ak", "friends:am")
connection.subscribe("passport:ak", "friends:mt")

event = Chronologic::Event.new
event.key = "checkin:1"
event.timestamp = Time.now
event.data = {"message" => "I'm giving a talk!"}
event.objects = {"user" => ["user:ak"], "spots" => ["spot:lsrc"]}
event.timelines = ["passport:ak"]

connection.publish(event)

subevent = Chronologic::Event.new
subevent.key = "comment:1"
subevent.timestamp = Time.now
subevent.data = {"message" => "Me too!"}
subevent.parent = "checkin:1"
subevent.objects = {"user" => ["user:rs"]}
subevent.timelines = ["checkin:1"]

connection.publish(subevent)

feed = connection.timeline("friends:rs")
pp feed['items'].first

feed = connection.timeline("friends:am")
pp feed['items'].first

feed = connection.timeline("friends:mt")
pp feed['items'].first

