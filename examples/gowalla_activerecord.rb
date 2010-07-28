#!/usr/bin/env ruby

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'chronologic'
require 'rubygems'
require 'active_record'

CHRONO = Chronologic::Connection.new
CHRONO.clear!

puts "Defining in-memory database..."
orig_stdout = $stdout
$stdout = File.new('/dev/null', 'w')
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => ":memory:")
ActiveRecord::Base.logger = Logger.new(nil)
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
  end
  create_table :spots do |t|
    t.string :name
  end
  create_table :trips do |t|
    t.string :name
  end
  create_table :checkins do |t|
    t.references :user, :spot
    t.string :message
    t.timestamps
  end
  create_table :pins do |t|
    t.references :user, :trip
    t.timestamps
  end
  create_table :comments do |t|
    t.references :user, :checkin
    t.string :message
    t.timestamps
  end
  create_table :photos do |t|
    t.references :user, :checkin
    t.string :message
    t.timestamps
  end
end
$stdout = orig_stdout

puts "Defining domain models..."
class User < ActiveRecord::Base
  has_many :checkins
  has_many :pins
  has_many :photos

  def follow(user)
    CHRONO.subscribe("user_#{id}_friends", "user_#{user.id}")
  end
  def unfollow(user)
    CHRONO.unsubscribe("user_#{id}_friends", "user_#{user.id}")
  end
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
  has_many :comments
  has_many :photos

  def after_save
    CHRONO.event("checkin_#{id}",
      :data => { :type => "checkin", :message => message },
      :created_at => created_at,
      :timelines => ["user_#{user_id}", "spot_#{spot_id}"],
      :subscribers => ["user_#{user_id}"],
      :objects => { :spot => "spot_#{spot_id}", :user => "user_#{user_id}" }
    )
  end
end

class Pin < ActiveRecord::Base
  belongs_to :user
  belongs_to :trip

  def after_save
    CHRONO.event("pin_#{id}",
      :data => { :type => "pin" },
      :created_at => created_at,
      :timelines => ["user_#{user_id}", "trip_#{trip_id}"],
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
      :created_at => created_at,
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
      :created_at => created_at,
      :objects => { :user => "user_#{user_id}" },
      :events => [ "checkin_#{checkin_id}" ]
    )
  end
end

class Timeline
  def initialize(key)
    @info = CHRONO.timeline(key)
  end
  def to_s
    lines = []
    @info[:events].each do |event|
      if event[:type]=='checkin'
        lines << "- #{event[:user][:name]} checked in at #{event[:spot][:name]}: \"#{event[:message]}\" (#{event[:created_at].strftime("%H:%M %a")})"
        (event[:events] || []).each do |subevent|
          if event[:type]=='comment'
            lines << "  - #{subevent[:user][:name]} commented: \"#{subevent[:message]}\" (#{subevent[:created_at].strftime("%H:%M %a")})"
          else
            # unknown event type
          end
        end
      elsif event[:type]=='pin'
        lines << "- #{event[:user][:name]} earned the #{event[:trip][:name]} pin"
      else
        # unknown event type
      end
    end
    lines.join("\n")
  end
end

puts "Creating users..."
jw = User.create(:name => 'Josh Williams')
iconmaster = User.create(:name => 'John Marstall')
etherbrian = User.create(:name => 'Brian Brasher')
sco = User.create(:name => 'Scott Raymond')
critzjm = User.create(:name => 'John Critz')
keeg = User.create(:name => 'Keegan Jones')

puts "Creating spots..."
gowalla = Spot.create(:name => 'Gowalla HQ')
juan = Spot.create(:name => 'Juan Pelota')
halcyon = Spot.create(:name => 'Halcyon')
apple = Spot.create(:name => 'Apple Store')
zilker = Spot.create(:name => 'Zilker Park')
driskill = Spot.create(:name => 'Driskill Hotel')
jos = Spot.create(:name => "Jo's Coffee")
onetaco = Spot.create(:name => 'One Taco')
gingerman = Spot.create(:name => 'Ginger Man')
walmart = Spot.create(:name => 'Walmart')

puts "Creating trips..."
coffeesnob = Trip.create(:name => "I'm a Coffee Snob!")
lush = Trip.create(:name => "I'm a Drunk!")
foodie = Trip.create(:name => "I'm a Fattie!")

puts "Users follow each other..."
jw.follow(iconmaster)
jw.follow(etherbrian)
jw.follow(sco)
jw.follow(critzjm)
jw.follow(keeg)
sco.follow(jw)
sco.follow(keeg)

puts "Users check in, earn pins, etc..."
sco.checkins.create(:spot => juan, :message => "Coffee break!", :created_at => 25.hours.ago)
sco.pins.create(:trip => coffeesnob, :created_at => 25.hours.ago)
sco.checkins.create(:spot => driskill, :message => "Drinks", :created_at => 12.hours.ago)
sco.checkins.create(:spot => jos, :message => "Charging up", :created_at => 4.hours.ago)
sco.checkins.create(:spot => gowalla, :message => "Building cool shit", :created_at => 45.minutes.ago)

checkin = keeg.checkins.create(:spot => gowalla, :message => "Working", :created_at => 15.hours.ago)
checkin.comments.create(:user => jw, :message => "Good!", :created_at => 14.hours.ago)
keeg.checkins.create(:spot => halcyon, :created_at => 5.hours.ago)
keeg.checkins.create(:spot => gingerman, :message => "Trivia night.", :created_at => 30.minutes.ago)
keeg.pins.create(:trip => lush, :created_at => 30.minutes.ago)

iconmaster.checkins.create(:spot => apple, :message => "Picking up a new mouse", :created_at => 10.hours.ago)
iconmaster.checkins.create(:spot => onetaco, :message => "Lunch!", :created_at => 1.hours.ago)
iconmaster.checkins.create(:spot => zilker, :created_at => 15.minutes.ago)

checkin = etherbrian.checkins.create(:spot => walmart, :message => "Just hanging out.", :created_at => 3.hours.ago)
checkin.comments.create(:user => sco, :message => "Haha LOL jk.", :created_at => 2.hours.ago)

critzjm.checkins.create(:spot => gowalla, :message => "Trackin' stats.", :created_at => 8.hours.ago)
critzjm.checkins.create(:spot => juan, :message => "Mmm, coffee.", :created_at => 2.hours.ago)

puts "\nScott's timeline:"
puts sco.timeline
puts

puts "Josh's friends timeline:"
puts jw.friends_timeline
puts
