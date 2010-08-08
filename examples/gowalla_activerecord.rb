#!/usr/bin/env ruby

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'chronologic'
require 'rubygems'
require 'active_record'

puts "Creating database and models..."
orig_stdout = $stdout
$stdout = File.new('/dev/null', 'w') # shush, activerecord!
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database  => ":memory:")
ActiveRecord::Base.logger = Logger.new(nil)
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
  end
  create_table :spots do |t|
    t.string :name
  end
  create_table :checkins do |t|
    t.references :user, :spot
    t.string :message
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
  create_table :trips do |t|
    t.string :name
  end
  create_table :pins do |t|
    t.references :user, :trip
    t.timestamps
  end
  create_table :kinds do |t|
    t.string :name
  end
  create_table :items do |t|
    t.references :kind, :user, :spot
    t.timestamps
  end
  create_table :highlight_types do |t|
    t.string :name
  end
  create_table :highlights do |t|
    t.references :highlight_type, :user, :spot
    t.string :message
    t.timestamps
  end
end
$stdout = orig_stdout

class User < ActiveRecord::Base
  has_many :checkins
  has_many :pins
  has_many :photos

  def follow(user)
    CHRONO.subscribe("user_#{id}_home", "user_#{user.id}")
  end
  def unfollow(user)
    CHRONO.unsubscribe("user_#{id}_home", "user_#{user.id}")
  end
  def after_save
    CHRONO.object("user_#{id}", { :name => name })
  end
  def timeline
    Timeline.new("user_#{id}")
  end
  def home_timeline(options={})
    Timeline.new("user_#{id}_home", options)
  end
end

class Spot < ActiveRecord::Base
  def after_save
    CHRONO.object("spot_#{id}", { :name => name })
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

class Trip < ActiveRecord::Base
  def after_save
    CHRONO.object("trip_#{id}", { :name => name })
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

class Kind < ActiveRecord::Base
  def after_save
    CHRONO.object("kind_#{id}", { :name => name })
  end
end

class Item < ActiveRecord::Base
  belongs_to :kind
  belongs_to :user
  belongs_to :spot

  def bonus_event(checkin)
    CHRONO.event("item_#{id}_bonus",
      :data => { :type => "item_bonus" },
      :created_at => checkin.created_at,
      :objects => { :kind => "kind_#{kind_id}" },
      :events => [ "checkin_#{checkin.id}" ],
      :timelines => [ "item_#{id}" ]
    )
  end

  def drop_event(checkin)
    CHRONO.event("item_#{id}_drop",
      :data => { :type => "item_drop" },
      :created_at => Time.now,
      :objects => { :kind => "kind_#{kind_id}" },
      :events => [ "checkin_#{checkin.id}" ],
      :timelines => [ "item_#{id}" ]
    )
  end

  # TODO: swap
  
  def vault_event
    CHRONO.event("item_#{id}_vault",
      :data => { :type => "item_vault" },
      :created_at => Time.now,
      :objects => { :kind => "kind_#{kind_id}" },
      :timelines => [ "item_#{id}" ]
    )
  end
end

class HighlightType < ActiveRecord::Base
  def after_save
    CHRONO.object("highlight_type_#{id}", { :name => name })
  end
end

class Highlight < ActiveRecord::Base
  belongs_to :highlight_type
  belongs_to :user
  belongs_to :spot

  def after_save
    CHRONO.event("highlight_#{id}",
      :data => { :type => "highlight", :message => message },
      :created_at => created_at,
      :objects => { :highlight_type => "highlight_type_#{highlight_type_id}", :user => "user_#{user_id}", :spot => "spot_#{spot_id}" },
      :timelines => ["user_#{user_id}", "highlight_type_#{highlight_type_id}", "spot_#{spot_id}"]
    )
  end
end

class Timeline
  def initialize(key, options={})
    @info = CHRONO.timeline(key, options)
  end
  def to_s
    lines = []
    @info[:events].each do |event|
      if event[:type]=='checkin'
        lines << "- #{event[:user][:name]} checked in at #{event[:spot][:name]}: \"#{event[:message]}\" (#{event[:created_at].strftime("%H:%M %a")})"
        (event[:events] || []).each do |subevent|
          if subevent[:type]=='comment'
            lines << "  - #{subevent[:user][:name]} commented: \"#{subevent[:message]}\""
          elsif subevent[:type]=='photo'
            lines << "  - #{subevent[:user][:name]} took a photo: \"#{subevent[:message]}\""
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



CHRONO = Chronologic::Connection.new
CHRONO.clear!

puts "Creating users, spots, trips, kinds, subscriptions..."
jw = User.create(:name => 'Josh Williams')
iconmaster = User.create(:name => 'John Marstall')
etherbrian = User.create(:name => 'Brian Brasher')
sco = User.create(:name => 'Scott Raymond')
critzjm = User.create(:name => 'John Critz')
keeg = User.create(:name => 'Keegan Jones')

jw.follow(iconmaster)
jw.follow(etherbrian)
jw.follow(sco)
jw.follow(critzjm)
jw.follow(keeg)
sco.follow(jw)
sco.follow(keeg)

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

coffeesnob = Trip.create(:name => "I'm a Coffee Snob!")
lush = Trip.create(:name => "I'm a Drunk!")
foodie = Trip.create(:name => "I'm a Fattie!")

Kind.create(:name => "some Ribs")
Kind.create(:name => "a Watering Can")
Kind.create(:name => "some Cutoffs")

puts "Users check in, earn pins, etc..."
50.downto(0) do |i|
  base = (i*24).hours

  sco.checkins.create(:spot => juan, :message => "Coffee break!", :created_at => 25.hours.ago - base)
  sco.pins.create(:trip => coffeesnob, :created_at => 25.hours.ago - base)
  sco.checkins.create(:spot => driskill, :message => "Drinks", :created_at => 12.hours.ago - base)
  sco.checkins.create(:spot => jos, :message => "Charging up", :created_at => 4.hours.ago - base)
  sco.checkins.create(:spot => gowalla, :message => "Building cool shit", :created_at => 45.minutes.ago - base)

  checkin = keeg.checkins.create(:spot => gowalla, :message => "Working", :created_at => 15.hours.ago - base)
  checkin.comments.create(:user => jw, :message => "Good!", :created_at => 14.hours.ago - base)
  keeg.checkins.create(:spot => halcyon, :created_at => 5.hours.ago - base)
  keeg.checkins.create(:spot => gingerman, :message => "Trivia night.", :created_at => 30.minutes.ago - base)
  keeg.pins.create(:trip => lush, :created_at => 30.minutes.ago - base)

  iconmaster.checkins.create(:spot => apple, :message => "Picking up a new mouse", :created_at => 10.hours.ago - base)
  iconmaster.checkins.create(:spot => onetaco, :message => "Lunch!", :created_at => 1.hours.ago - base)
  iconmaster.checkins.create(:spot => zilker, :created_at => 15.minutes.ago - base)

  checkin = etherbrian.checkins.create(:spot => walmart, :message => "Just hanging out.", :created_at => 3.hours.ago - base)
  checkin.comments.create(:user => etherbrian, :message => "Haha LOL jk.", :created_at => 2.hours.ago - base)

  critzjm.checkins.create(:spot => gowalla, :message => "Trackin' stats.", :created_at => 8.hours.ago - base)
  checkin = critzjm.checkins.create(:spot => juan, :message => "Mmm, coffee.", :created_at => 2.hours.ago - base)
  checkin.photos.create(:user => critzjm, :message => "Here's a picture of it.", :created_at => 2.hours.ago - base)
  checkin.comments.create(:user => sco, :message => "Looks good.", :created_at => 2.hours.ago - base)

  # TODO: drop/swap some items
end

puts "Press enter to get timelines...";
gets;

puts "Scott's user timeline:"
puts sco.timeline
puts

puts "Josh's home timeline:"
puts jw.home_timeline#(:count => 10)
puts
