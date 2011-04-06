require 'pp'
require 'chronologic'

cl = Chronologic::Client.new('http://localhost:9292')

user = 'grouping_user_0'

events = 2.times.map do |i|
  event = Chronologic::Event.new.tap do |e|
    e.key = "grouping_checkin_#{i}"
    e.timestamp = Time.now + i
    e.data = {'message' => "This is checkin #{i}"}
    e.timelines = [user]
  end

  cl.publish(event)
  event
end

subevents = events.each_with_index do |parent, i|
  subevent = Chronologic::Event.new.tap do |e|
    e.key = "grouping_comment_#{i}"
    e.timestamp = Time.now + i
    e.data = {'comment' => "Gymnopadie #{i}"}
    e.parent = parent.key
    e.timelines = [parent.key]
  end

  cl.publish(subevent)
  subevent
end

grouping = Chronologic::Event.new.tap do |e|
  e.key = "grouping"
  e.timestamp = Time.now
  e.data = {"grouping" => 'BOOM'}
  e.timelines = [user]
end
cl.publish(grouping)

events.each do |e|
  cl.unpublish(e.key)
  e.parent = grouping.key
  e.timelines = [grouping.key]
  cl.publish(e)
end

pp cl.timeline('grouping')["feed"]

[grouping, events, subevents].flatten.each { |e| cl.unpublish(e.key) }
