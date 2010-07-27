#!/usr/bin/env ruby

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'chronologic'
require 'rubygems'
require 'active_record'

CHRONO = Chronologic::Client.new
CHRONO.clear!

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => ":memory:")
ActiveRecord::Schema.define do
  create_table :users do |table|
    table.column :name, :string
  end
  create_table :spots do |table|
    table.column :name, :string
  end
  create_table :trips do |table|
    table.column :name, :string
  end
  create_table :checkins do |table|
    table.column :user_id, :integer
    table.column :spot_id, :integer
    table.column :message, :string
  end
  create_table :pins do |table|
    table.column :user_id, :integer
    table.column :trip_id, :integer
  end
  create_table :comments do |table|
    table.column :user_id, :integer
    table.column :checkin_id, :integer
    table.column :message, :string
  end
  create_table :photos do |table|
    table.column :user_id, :integer
    table.column :checkin_id, :integer
    table.column :message, :string
  end
end

class User < ActiveRecord::Base
  has_many :checkins
  has_many :pins

  def follow(user)
    CHRONO.subscribe("user_#{id}_friends", "user_#{user.id}")
  end
  #def unfollow(user)
  #  CHRONO.unsubscribe("user_#{id}_friends", "user_#{user.id}")
  #end
  def after_save
    CHRONO.object("user_#{id}", { :name => name })
  end
  def timeline
    Timeline.new("user_#{id}")
  end
  def friends_timeline
    Timeline.new("user_#{id}_friends")
  end
end

class Spot < ActiveRecord::Base
  def after_save
    CHRONO.object("spot_#{id}", { :name => name })
  end
end

class Trip < ActiveRecord::Base
  def after_save
    CHRONO.object("trip_#{id}", { :name => name })
  end
end

class Checkin < ActiveRecord::Base
  belongs_to :user
  belongs_to :spot

  def after_save
    CHRONO.event("checkin_#{id}",
      :timelines => ["user_#{user_id}"],
      :subscribers => ["user_#{user_id}"],
      :data => { :type => "checkin", :message => message },
      :objects => { :spot => "spot_#{spot_id}", :user => "user_#{user_id}" }
    )
  end
end

class Pin < ActiveRecord::Base
  belongs_to :user
  belongs_to :trip

  def after_save
    CHRONO.event("pin_#{id}",
      :timelines => ["user_#{user_id}"],
      :data => { :type => "pin" },
      :objects => { :trip => "trip_#{trip_id}", :user => "user_#{user_id}" }
    )
  end
end

class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :checkin

  def after_save
    CHRONO.event("comment_#{id}",
      :data => { :type => "comment", :message => message },
      :objects => { :user => "user_#{user_id}" },
      :events => [ "checkin_#{checkin_id}" ]
    )
  end
end

class Photo < ActiveRecord::Base
  belongs_to :user
  belongs_to :checkin

  def after_save
    CHRONO.event("photo_#{id}",
      :data => { :type => "photo", :message => message },
      :objects => { :user => "user_#{user_id}" },
      :events => [ "checkin_#{checkin_id}" ]
    )
  end
end

class Timeline
  def initialize(key)
    @events = CHRONO.timeline(key)
  end
  def to_s
    @events.map do |event|
      if event[:type]=='checkin'
        "- #{event[:user][:name]} checked in at #{event[:spot][:name]}: \"#{event[:message]}\""
      elsif event[:type]=='pin'
        "- #{event[:user][:name]} earned the #{event[:trip][:name]} pin"
      else
        "(unknown event type)"
      end
    end.join("\n")
  end
end

puts "Creating users, spots, trips"
sco = User.create(:name => 'Scott Raymond')
jw = User.create(:name => 'Josh Williams')
keeg = User.create(:name => 'Keegan Jones')
work = Spot.create(:name => 'Gowalla HQ')
juan = Spot.create(:name => 'Juan Pelota')
coffee = Trip.create(:name => 'Visit a Coffeeshop')

puts "Josh follows Scott"
jw.follow(sco)

puts "Scott checks in and earns a pin"
sco.checkins.create(:spot => juan, :message => "Coffee break!")
sco.pins.create(:trip => coffee)

puts "Scott's timeline"
puts sco.timeline

puts "Josh's friends timeline"
puts jw.friends_timeline
