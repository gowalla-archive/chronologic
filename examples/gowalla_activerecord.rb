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
  create_table :trips do |t|
    t.string :name
  end
  create_table :kinds do |t|
    t.string :name
    t.string :determiner
  end
  create_table :highlight_types do |t|
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
  create_table :pins do |t|
    t.references :user, :trip
    t.timestamps
  end
  create_table :items do |t|
    t.references :kind, :user, :spot
    t.integer :number
    t.timestamps
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
  has_many :highlights

  def follow(user)
    CHRONO.subscribe("user_#{id}_home", "user_#{user.id}")
  end
  def unfollow(user)
    CHRONO.unsubscribe("user_#{id}_home", "user_#{user.id}")
  end
  def after_save
    CHRONO.object("user_#{id}", { :name => name })
  end
  def timeline(options={})
    options.reverse_merge!(:count => 25)
    GowallaTimeline.new("user_#{id}", options)
  end
  def home_timeline(options={})
    options.reverse_merge!(:count => 25)
    GowallaTimeline.new("user_#{id}_home", options)
  end
end

class Spot < ActiveRecord::Base
  def after_save
    CHRONO.object("spot_#{id}", { :name => name })
  end

  def timeline(options={})
    options.reverse_merge!(:count => 25)
    GowallaTimeline.new("spot_#{id}", options)
  end
end

class Trip < ActiveRecord::Base
  def after_save
    CHRONO.object("trip_#{id}", { :name => name })
  end

  def timeline(options={})
    options.reverse_merge!(:count => 25)
    GowallaTimeline.new("trip_#{id}", options)
  end
end

class Kind < ActiveRecord::Base
  def after_save
    CHRONO.object("kind_#{id}", { :name => name, :determiner => determiner })
  end
end

class HighlightType < ActiveRecord::Base
  def after_save
    CHRONO.object("highlight_type_#{id}", { :name => name })
  end
end

class Checkin < ActiveRecord::Base
  belongs_to :user
  belongs_to :spot
  has_many :comments
  has_many :photos

  def after_save
    CHRONO.event(
      :key => "checkin_#{id}",
      :created_at => created_at,
      :data => { :type => "checkin", :message => message },
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
    CHRONO.event(
      :key => "comment_#{id}",
      :created_at => created_at,
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
    CHRONO.event(
      :key => "photo_#{id}",
      :created_at => created_at,
      :data => { :type => "photo", :message => message },
      :objects => { :user => "user_#{user_id}" },
      :events => [ "checkin_#{checkin_id}" ]
    )
  end
end

class Pin < ActiveRecord::Base
  belongs_to :user
  belongs_to :trip

  def after_save
    CHRONO.event(
      :key => "pin_#{id}",
      :created_at => created_at,
      :data => { :type => "pin" },
      :timelines => ["user_#{user_id}", "trip_#{trip_id}"],
      :objects => { :trip => "trip_#{trip_id}", :user => "user_#{user_id}" }
    )
  end
end

class Item < ActiveRecord::Base
  belongs_to :kind
  belongs_to :user
  belongs_to :spot

  def before_create
    write_attribute :number, 1
  end

  def after_save
    CHRONO.object("item_#{id}", { :number => number })
  end

  def bonus_event(checkin)
    CHRONO.event(
      :key => "item_#{id}_bonus",
      :created_at => checkin.created_at,
      :data => { :type => "item_bonus" },
      :objects => { :kind => "kind_#{kind_id}", :item => "item_#{id}" },
      :events => [ "checkin_#{checkin.id}" ],
      :timelines => [ "item_#{id}" ]
    )
  end

  def drop_event(checkin)
    CHRONO.event(
      :key => "item_#{id}_drop",
      :created_at => Time.now,
      :data => { :type => "item_drop" },
      :objects => { :kind => "kind_#{kind_id}", :item => "item_#{id}" }, # store the spot and user, for the item feed?
      :events => [ "checkin_#{checkin.id}" ],
      :timelines => [ "item_#{id}" ]
    )
  end
  
  def pickup_event(checkin, dropped_item)
    CHRONO.event(
      :key => "item_#{id}_pickup",
      :created_at => Time.now,
      :data => { :type => "item_pickup" },
      :objects => {
        :picked_up_kind => "kind_#{kind_id}",
        :picked_up_item => "item_#{id}",
        :dropped_kind => "kind_#{dropped_item.kind_id}",
        :dropped_item => "item_#{dropped_item.id}"
      },
      :events => [ "checkin_#{checkin.id}" ],
      :timelines => [ "item_#{id}", "item_#{dropped_item.id}" ]
    )
  end
  
  def vault_event
    CHRONO.event(
      :key => "item_#{id}_vault",
      :created_at => Time.now,
      :data => { :type => "item_vault" },
      :objects => { :kind => "kind_#{kind_id}", :item => "item_#{id}" },
      :timelines => [ "item_#{id}" ]
    )
  end

  def timeline(options={})
    options.reverse_merge!(:count => 25)
    GowallaTimeline.new("item_#{id}", options)
  end
end

class Highlight < ActiveRecord::Base
  belongs_to :highlight_type
  belongs_to :user
  belongs_to :spot

  def after_save
    CHRONO.event(
      :key => "highlight_#{id}",
      :created_at => created_at,
      :data => { :type => "highlight", :message => message },
      :objects => { :highlight_type => "highlight_type_#{highlight_type_id}", :user => "user_#{user_id}", :spot => "spot_#{spot_id}" },
      :timelines => ["user_#{user_id}", "highlight_type_#{highlight_type_id}", "spot_#{spot_id}"],
      :subscribers => ["user_#{user_id}"]
    )
  end
end

class GowallaTimeline
  def initialize(key, options={})
    @key = key
    @options = options
  end
  
  def next
    self.class.new(@key, @options.merge(:start => info[:finish]))
  end

  def info
    @info ||= CHRONO.timeline(@key, @options)
  end

  def to_s
    info[:events].map do |event_info|
      if event_info[:type]=='checkin'
        str = "- #{event_info[:user][:name]} checked in at #{event_info[:spot][:name]}: \"#{event_info[:message]}\" (#{event_info[:created_at].strftime("%H:%M %a")})"
        (event_info[:events] || []).each do |subevent|
          if subevent[:type]=='comment'
            str << "\n  - #{subevent[:user][:name]} commented: \"#{subevent[:message]}\""
          elsif subevent[:type]=='photo'
            str << "\n  - #{subevent[:user][:name]} took a photo: \"#{subevent[:message]}\""
          elsif subevent[:type]=='item_drop'
            str << "\n  - #{event_info[:user][:name]} dropped #{subevent[:kind][:name]} ##{subevent[:item][:number]}"
          elsif subevent[:type]=='item_bonus'
            str << "\n  - #{event_info[:user][:name]} received #{subevent[:kind][:name]}"
          else
            str << "\n  - (unknown event type: #{subevent.inspect})"
          end
        end
        str
      elsif event_info[:type]=='pin'
        "- #{event_info[:user][:name]} earned the #{event_info[:trip][:name]} pin (#{event_info[:created_at].strftime("%H:%M %a")})"
      elsif event_info[:type]=='highlight'
        "- #{event_info[:user][:name]} made #{event_info[:spot][:name]} a highlight: #{event_info[:highlight_type][:name]} (#{event_info[:created_at].strftime("%H:%M %a")})"
      elsif event_info[:type]=='item_bonus'
        "- #{event_info[:kind][:name]} ##{event_info[:item][:number]} was received (#{event_info[:created_at].strftime("%H:%M %a")})"
      elsif event_info[:type]=='item_drop'
        "- #{event_info[:kind][:name]} ##{event_info[:item][:number]} was dropped (#{event_info[:created_at].strftime("%H:%M %a")})"
      else
        "- (unknown event type: #{event_info[:type]})"
      end
    end.join("\n")
  end
end


CHRONO = Chronologic::Client.new
CHRONO.clear!

puts "Creating users..."
jw = User.create(:name => 'Josh Williams')
iconmaster = User.create(:name => 'John Marstall')
etherbrian = User.create(:name => 'Brian Brasher')
sco = User.create(:name => 'Scott Raymond')
critzjm = User.create(:name => 'John Critz')
keeg = User.create(:name => 'Keegan Jones')

puts "Creating subscriptions..."
jw.follow(iconmaster)
jw.follow(etherbrian)
jw.follow(sco)
jw.follow(critzjm)
jw.follow(keeg)
sco.follow(jw)
sco.follow(keeg)

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

puts "Creating kinds..."
ribs = Kind.create(:determiner => "some", :name => "Ribs")
wateringcan = Kind.create(:determiner => "a", :name => "Watering Can")
cutoffs = Kind.create(:determiner => "some", :name => "Cutoffs")

puts "Creating highlight types..."
happyplace = HighlightType.create(:name => "My Happy Place")
bestcup = HighlightType.create(:name => "Best Cup")

10.downto(0) do |i|
  puts "Creating checkins, pins, photos, comments, items, highlights etc..."
  base = (i*24).hours

  sco.checkins.create(:spot => juan, :message => "Coffee break!", :created_at => 25.hours.ago - base)
  sco.pins.create(:trip => coffeesnob, :created_at => 25.hours.ago - base)
  sco.checkins.create(:spot => driskill, :message => "Drinks", :created_at => 12.hours.ago - base)
  sco.checkins.create(:spot => jos, :message => "Charging up", :created_at => 4.hours.ago - base)
  checkin = sco.checkins.create(:spot => gowalla, :message => "Building cool shit", :created_at => 45.minutes.ago - base)
  item = Item.create(:user => sco, :kind => cutoffs)
  item.bonus_event(checkin)
  item.drop_event(checkin)
  sco.highlights.create(:spot => gingerman, :highlight_type => happyplace, :message => "Mmm, beer", :created_at => 20.hours.ago - base)

  checkin = keeg.checkins.create(:spot => gowalla, :message => "Working", :created_at => 15.hours.ago - base)
  checkin.comments.create(:user => jw, :message => "Good!", :created_at => 14.hours.ago - base)
  keeg.checkins.create(:spot => halcyon, :created_at => 5.hours.ago - base)
  keeg.checkins.create(:spot => gingerman, :message => "Trivia night.", :created_at => 30.minutes.ago - base)
  keeg.pins.create(:trip => lush, :created_at => 30.minutes.ago - base)
  keeg.highlights.create(:spot => juan, :highlight_type => bestcup, :message => "Mmm, coffee", :created_at => 10.hours.ago - base)

  iconmaster.checkins.create(:spot => apple, :message => "Picking up a new mouse", :created_at => 10.hours.ago - base)
  iconmaster.checkins.create(:spot => onetaco, :message => "Lunch!", :created_at => 1.hours.ago - base)
  iconmaster.checkins.create(:spot => zilker, :created_at => 15.minutes.ago - base)

  checkin = etherbrian.checkins.create(:spot => walmart, :message => "Just hanging out.", :created_at => 3.hours.ago - base)
  checkin.comments.create(:user => etherbrian, :message => "Haha LOL jk.", :created_at => 2.hours.ago - base)

  critzjm.checkins.create(:spot => gowalla, :message => "Trackin' stats.", :created_at => 8.hours.ago - base)
  checkin = critzjm.checkins.create(:spot => juan, :message => "Mmm, coffee.", :created_at => 2.hours.ago - base)
  checkin.photos.create(:user => critzjm, :message => "Here's a picture of it.", :created_at => 2.hours.ago - base)
  checkin.comments.create(:user => sco, :message => "Looks good.", :created_at => 2.hours.ago - base)
end
puts

puts "Scott's user timeline:"
puts sco.timeline
puts

puts "Spot timeline:"
puts gowalla.timeline
puts

puts "Trip timeline:"
puts lush.timeline
puts

#puts "Item timeline:"
#puts Item.first.timeline
#puts

puts "Josh's home timeline:"
timeline = jw.home_timeline
puts timeline
puts

# puts "Next page of Josh's home timeline:"
# timeline = timeline.next
# puts timeline
# puts