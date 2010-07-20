#!/usr/bin/env ruby

$:.unshift 'lib'
require 'rubygems'
require 'chronologic'

c = Chronologic::Connection.new
c.clear!

# users are sco, jw, and keeg
c.insert_object(:user_1, {:name => 'sco'})
c.insert_object(:user_2, {:name => 'jw'})
c.insert_object(:user_3, {:name => 'keeg'})

# jw follows sco and keeg
c.insert_subscription(:user_2_friends, :user_1)
c.insert_subscription(:user_2_friends, :user_3)

# sco tweets
c.insert_event(:info => { :text => 'O HAI' }, :timelines => [:user_1], :subscribers => [:user_1], :objects => { :user => :user_1 })

# keeg tweets
c.insert_event(:info => { :text => 'HELLO' }, :timelines => [:user_3], :subscribers => [:user_3], :objects => { :user => :user_3 })

# josh requests his timeline
puts c.get_timeline(:user_2_friends).to_yaml
