#!/usr/bin/env ruby

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'chronologic'

c = Chronologic::Client.new
c.clear!

puts "creating user objects"
c.object(:user_1, {:name => 'sco'})
c.object(:user_2, {:name => 'jw'})
c.object(:user_3, {:name => 'keeg'})

puts "jw follows sco and keeg"
c.subscribe(:user_2_friends, :user_1)
c.subscribe(:user_2_friends, :user_3)

puts "sco tweets"
c.event(:status_1,
  :data => { :text => 'O HAI' },
  :timelines => [:user_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1 }
)

puts "keeg tweets"
c.event(:status_2,
  :data => { :text => 'HELLO' },
  :timelines => [:user_3],
  :subscribers => [:user_3],
  :objects => { :user => :user_3 }
)

puts "josh's friends timeline:"
puts c.timeline(:user_2_friends).to_yaml
