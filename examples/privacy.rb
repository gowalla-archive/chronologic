require 'chronologic'

cl = Chronologic::Client.new('http://localhost:9292')

# AK is public and friends with BF and BO
cl.subscribe('user_ak_feed', 'user_bf')
cl.subscribe('user_ak_feed', 'user_bo')

# BF is public and friends with BO and AK
cl.subscribe('user_bf_feed', 'user_bo')
cl.subscribe('user_bf_feed', 'user_ak')

# BO is private and friends with BF and AK
cl.subscribe('user_bo_feed', 'user_bf')
cl.subscribe('user_bo_feed', 'user_ak')

# BS is public shares with BO but BO does not reciprocate
cl.subscribe('user_bs_feed', 'user_bo')

# BO checks in
event = Chronologic::Event.new(
  :key => 'checkin_1',
  :timestamp => Time.now,
  :data => {:message => "I'm here!"},
  :objects => {'user' => 'user_bo', 'spot' => 'spot_1'},
  :timelines => ['user_bo']
)
# TODO
# event.private = true
cl.publish(event)

# BF and AK and see BO's checkin
p cl.timeline('user_bf_home')['items'] # Should include BO's event
p cl.timeline('user_ak_home')['items'] # Should include BO's event

# BS cannot see BO's checkin
cl.timeline('user_bs_home') # Should not include BO's event

if defined?(CL::Subscriber)
  ## Now let's write this with a CL model
  
  ak = CL::Subscriber.new('user_ak_home')
  bf = CL::Subscriber.new('user_bf_home')
  bo = CL::Subscriber.new('user_bo_home')
  bs = CL::Subscriber.new('user_bs_home')

  bo.subscribe_to(ak.timeline_key)
  bo.subscribe_to(bf.timeline_key)

  ak.subcribe_to(bo.timeline_key)
  bf.subscribe_to(bo.timeline_key)
  bs.subscribe_to(bo.timeline_key)

  event = CL::Event.new(
    :key => 'checkin_1',
    :data => {:message => "I'm here!"},
    :objects => {'user' => bo, 'spot' => 'spot_1'},
    :timelines => [bo.timeline_key],
    :private => true
  )
  event.publish!

  ak_timeline = CL::Timeline.new(ak.feed_key)
  p ak_timeline.fetch # Should include BO's event

  bf_timeline = CL::Timeline.new(bf.feed_key)
  p bf_timeline.fetch # Should include BO's event

  bs_timeline = CL::Timeline.new(bs.feed_key)
  p bs_timeline.fetch # Should _not_ include BO's event
end
