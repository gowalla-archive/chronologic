$:.unshift 'lib'
require 'chronologic'

c = Chronologic::Connection.new
c.clear!

# Update the object cache when a spot/user/etc is saved
c.object(:user_1, {:name => 'Scott Raymond'})
c.object(:user_2, {:name => 'Josh Williams'})
c.object(:spot_1, {:name => 'Gowalla HQ'})
c.object(:spot_2, {:name => 'Juan Pelota'})
c.object(:trip_1, {:name => 'Visit 3 Coffeeshops!'})
c.object(:highlight_type_1, {:name => 'My Happy Place'})

# Update the subscriptions cache when one user follows another, etc.
c.subscribe(:user_2_friends, :user_1)

# Store a checkin
c.event(
  :info => { :type => 'checkin', :id => '1', :message => 'Hello' },
  :key => :checkin_1,
  :timelines => [:user_1, :spot_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :spot => :spot_1 }
)

# Store a pin
c.event(
  :info => { :type => 'pin', :id => '1' },
  :key => :pin_1,
  :timelines => [:user_1, :trip_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :trip => :trip_1 }
)

# Store a highlight
c.event(
  :info => { :type => 'highlight', :id => '1' },
  :key => :highlight_1,
  :timelines => [:user_1, :highlight_type_1],
  :subscribers => [:user_1],
  :objects => { :user => :user_1, :highlight_type => :highlight_type_1 }
)

# Store a comment
c.event(
  :info => { :type => 'comment', :id => '1', :message => 'Nice!' },
  :key => :comment_1,
  :objects => { :user => :user_2 },
  :events => [ :checkin_1 ]
)

# Request a timeline
puts c.timeline(:user_2_friends).to_yaml
