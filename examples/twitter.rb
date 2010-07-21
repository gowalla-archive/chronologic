#!/usr/bin/env ruby

$:.unshift 'lib'
require 'rubygems'
require 'chronologic'

c = Chronologic::Connection.new
c.clear!

# users are sco, jw, and keeg
c.object(:user_1, {:name => 'sco'})
c.object(:user_2, {:name => 'jw'})
c.object(:user_3, {:name => 'keeg'})

# jw follows sco and keeg
c.subscribe(:user_2_friends, :user_1)
c.subscribe(:user_2_friends, :user_3)

# sco tweets
c.event(:info => { :text => 'O HAI' }, :timelines => [:user_1], :subscribers => [:user_1], :objects => { :user => :user_1 })

# keeg tweets
c.event(:info => { :text => 'HELLO' }, :timelines => [:user_3], :subscribers => [:user_3], :objects => { :user => :user_3 })

# josh requests his timeline
puts c.timeline(:user_2_friends).to_yaml
