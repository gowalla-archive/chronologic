#!/usr/bin/env ruby

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'chronologic'

c = Chronologic::Client.new
c.clear!

puts "Create objects for users, spots, trips, highlights"
c.object(:user_1, {:name => 'Scott Raymond'})
c.object(:user_2, {:name => 'Josh Williams'})
c.object(:spot_1, {:name => 'Gowalla HQ'})
c.object(:spot_2, {:name => 'Juan Pelota'})
c.object(:trip_1, {:name => 'Visit 3 Coffeeshops!'})
c.object(:highlight_type_1, {:name => 'My Happy Place'})

puts "Update the subscriptions cache when one user follows another, etc."
c.subscribe(:user_2_friends, :user_1)

20.downto(0) do |i|
  base = (i*24) * 60 * 60

  puts "Store a checkin"
  c.event(
    :key => :checkin_1,
    :created_at => Time.now - base - 5 * 60,
    :data => { :type => 'checkin', :id => '1', :message => 'Hello' },
    :timelines => [:user_1, :spot_1],
    :subscribers => [:user_1],
    :objects => { :user => :user_1, :spot => :spot_1 }
  )

  puts "Store a pin"
  c.event(
    :key => :pin_1,
    :created_at => Time.now - base - 10 * 60,
    :data => { :type => 'pin', :id => '1' },
    :timelines => [:user_1, :trip_1],
    :subscribers => [:user_1],
    :objects => { :user => :user_1, :trip => :trip_1 }
  )

  puts "Store a highlight"
  c.event(
    :key => :highlight_1,
    :created_at => Time.now - base - 15 * 60,
    :data => { :type => 'highlight', :id => '1' },
    :timelines => [:user_1, :highlight_type_1],
    :subscribers => [:user_1],
    :objects => { :user => :user_1, :highlight_type => :highlight_type_1 }
  )

  puts "Store a comment"
  c.event(
    :key => :comment_1,
    :created_at => Time.now - base - 20 * 60,
    :data => { :type => 'comment', :id => '1', :message => 'Nice!' },
    :objects => { :user => :user_2 },
    :events => [ :checkin_1 ]
  )
end

puts "Request a timeline"
puts c.timeline(:user_2_friends).to_yaml
