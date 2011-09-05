require "pp"
require "chronologic"

Chronologic.connection = Cassandra.new("ChronologicTest")

puts "Paginating with Chronologic::Schema"
page = Chronologic::Schema.timeline_for("user_1165", :per_page => 5).keys
puts "First/last: #{page.first}/#{page.last}"
pp Chronologic::Schema.timeline_for("user_1165", :per_page => 5, :page => page.last)

puts
puts "Paginating with Chronologic::Feed"
feed = Chronologic::Feed.new("user_1165", 5)
feed.fetch
puts "First/last: #{feed.previous_page}/#{feed.next_page}"
# pp Chronologic::Feed.fetch("user_1165", :per_page => 5, :page => feed.next_key)
puts
puts "Paginating with Chronologic::Feed and will_paginate"
feed = Chronologic::Feed.new("user_1165", 5)
feed.fetch
puts "First/last: #{feed.previous_page}/#{feed.next_page}"
next_feed = Chronologic::Feed.new("user_1165", 5, feed.next_page)
next_feed.fetch
puts "First/last: #{next_feed.previous_page}/#{next_feed.next_page}"
