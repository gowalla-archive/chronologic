$:.unshift 'lib'
require 'chronologic'

c = Chronologic::Connection.new
c.clear!

# Update the object cache when a spot/user/etc is saved
c.insert_object(:user_1, {:name => 'Scott Raymond'})
c.insert_object(:user_2, {:name => 'Josh Williams'})
c.insert_object(:spot_1, {:name => 'Gowalla HQ'})
c.insert_object(:spot_2, {:name => 'Juan Pelota'})
c.insert_object(:trip_1, {:name => 'Visit 3 Coffeeshops!'})
c.insert_object(:highlight_type_1, {:name => 'My Happy Place'})

# Update the subscriptions cache when one user follows another, etc.
c.insert_subscription(:user_2_friends, :user_1)
c.get_subscribers(:user_1)

# Store a checkin
c.insert_event(
  :info => { :type => 'checkin', :id => '1', :message => 'Hello' },
  :key => :checkin_1,
  :timelines => [:user_1, :spot_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :spot => :spot_1 }
)

# Store a pin
c.insert_event(
  :info => { :type => 'pin', :id => '1' },
  :key => :pin_1,
  :timelines => [:user_1, :trip_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :trip => :trip_1 }
)

# Store a highlight
c.insert_event(
  :info => { :type => 'highlight', :id => '1' },
  :key => :highlight_1,
  :timelines => [:user_1, :highlight_type_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :highlight_type => :highlight_type_1 }
)

# Store a comment
c.insert_event(
  :info => { :type => 'comment', :id => '1', :message => 'Nice!' },
  :key => :comment_1,
  :objects => { :user => :user_2 },
  :events => [ :checkin_1 ]
)

# Request a timeline
puts c.get_timeline(:user_2_friends).to_yaml
