Chronologic: activity feeds as a service
========================================

Chronologic is a library for managing activity feeds (aka news feeds or timelines), 
like Twitter, or just about any social network. It uses Cassandra. It's meant to be
easy to scale, be we shall see.


Overview
--------

Suppose you want to create a Twitter. Users can add tweets to their timeline, and
view a user's tweets in reverse-chronological order.

	# Create a connection
    chronologic = Chronologic::Connection.new

	# Scott creates some tweets
    chronologic.event(:timelines => [:sco], :info => { :text => 'Hello, world.' })
    chronologic.event(:timelines => [:sco], :info => { :text => 'Hello again.' })

	# Get all of Scott's tweets
	chronologic.timeline(:sco) # => [{"text"=>"Hello again."}, {"text"=>"Hello, world."}]

Nothing fancy. But all of the information is stored in Cassandra, which provides
extremely high write performance, and automatic partitioning of data across multiple nodes.

Swell. But you don't want to look at just one user's tweets at a time -- you want to
follow a bunch of users, and then get their messages aggregated. To do that, you'll
create some _subscriptions_.

	# Scott follows Josh and Keegan
    chronologic.subscribe(:sco_friends, :jw)
    chronologic.subscribe(:sco_friends, :keeg)

	# Josh and Keegan tweet
    chronologic.event(:timelines => [:jw], :subscribers => [:jw], :info => { :text => 'This is Josh.' })
    chronologic.event(:timelines => [:keeg], :subscribers => [:keeg], :info => { :text => 'This is Keegan.' })

	# Gets Scott's friends' tweets
	chronologic.timeline(:sco_friends) # => [{:text=>"This is Keegan."}, {:text=>"This is Josh."}]

Alright, but you really need to know which user made each tweet, not just the text.
And to display it in a feed, you'll also want their name, image URL, etc. To do that,
you'll create some _objects_. 

    # Store some metadata for Scott, Josh, and Keegan
    chronologic.object(:sco, {:name => 'Scott Raymond', :image_url => "http://..."})
    chronologic.object(:jw, {:name => 'Josh Williams', :image_url => "http://..."})
    chronologic.object(:keeg, {:name => 'Keegan Jones', :image_url => "http://..."})

	# Keegan tweets again
    chronologic.event(:timelines => [:keeg], :subscribers => [:keeg], :objects => { :user => :keeg }, :info => { :text => 'Me again.' })

	# Gets Scott's friends' tweets again -- this time, with embedded user info
	chronologic.timeline(:sco_friends) # => [{:text=>"Me again.", :user=>{:name=>"Keegan Jones", :image_url=>"http://..."}}]

All fine and good, but what if you want to add comments, or likes, to tweets? No problem;
you can add an event that's not attached to any particular timeline, but is attached to
another event.

    chronologic.event(:events => [:tweet_1], :objects => { :user => :sco }, :info => { :text => 'Nice tweet!' })

Say you want to get crazy and include more than just tweets in a timeline. Cassandra is
schemaless, so the structure of objects and event-info hashes is entirely arbitrary. Just
add a "type" property or something to help you distinguish event types.

    chronologic.event(:timelines => [:sco], :info => { :type => 'ad', :text => 'This is a message from our sponsor...' })

What happens if a user changes their image? Or deletes a tweet? Or un-follows a friend?

    # TODO


Installation & Configuration
----------------------------

Install chronologic:

    sudo gem install chronologic

Edit conf/storage-conf.xml to define the keyspace:

    <Keyspace Name="Chronologic">
      <ColumnFamily Name="Object" CompareWith="UTF8Type" />
      <ColumnFamily Name="Subscription" CompareWith="UTF8Type" />
      <ColumnFamily Name="Event" ColumnType="Super" CompareWith="UTF8Type" CompareSubcolumnsWith="UTF8Type" />
      <ColumnFamily Name="Timeline" CompareWith="TimeUUIDType" />

      <ReplicaPlacementStrategy>org.apache.cassandra.locator.RackUnawareStrategy</ReplicaPlacementStrategy>
      <ReplicationFactor>1</ReplicationFactor>
      <EndPointSnitch>org.apache.cassandra.locator.EndPointSnitch</EndPointSnitch>
    </Keyspace>

Start cassandra:
    cd ~/Desktop/apache-cassandra-0.6.3/
    export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home
    export PATH=$JAVA_HOME/bin:$PATH
    bin/cassandra -f

Start server:
    shotgun


Examples
--------

See the examples/ directory.


Meta
----
* Author:
  * Scott Raymond
  * <sco@scottraymond.net>
  * <http://twitter.com/sco>
* Code: `git clone git://github.com/gowalla/chronologic.git`
* Home: <http://github.com/gowalla/chronologic>
* Docs: <http://gowalla.github.com/chronologic/>
* Bugs: <http://github.com/gowalla/chronologic/issues>
* Gems: <http://rubygems.org/gems/chronologic>


TODO
----
- sub-events
- web UI
- get some specs running
- set up gem
- document/streamline cassandra installation
- recommend using the HTTP interface, or directly through Chronologic::Connection?
- enqueue fanout? or will it be fast enough? what if cassandra is temporarily down?
  - even though writes are fast, maybe they should still be triggered by a queue, so that we can group together notifications, publishing, etc., and pause cassandra sometimes.
- this system won't help scale the checkins, itemevents, etc tables. but it should help us read from them less.
- store pins, highlights, etc
- etag/if-modified-since etc?
- can this system become the basis for the PSHB feeds, the notifications system (APS and atom-based), and the real-time web notifications?
- how do we tell the system that some timelines should be capped, and some should be infinite?
- store sub-events, like comments, likes, item-events, etc
- handle deletes/changes/attachments (comments, photos, etc)
- adding a subscription adds events to the right timelines
- store copies of user names, user images, spot names, etc.? if not, we're hitting the main db to get it. if so, how do we keep everything consistent?
- store its own copy of the social graph, or rely on an external one?
- allow following spots and chains someday
- event clustering? (so your friends-feed can't be overrun by one hyper checker-inner)
- privacy: does a checkin get published to the spot feed even if the user is private? if I look at a spot feed, shouldn't I see my private friends?
- system should be responsible for notifications, and the real-time aspect, too.
- when/why should key be UUIDs?
- suppose we want to cap each timeline to 1000 or so -- how? maybe we don't cap user-feeds, but we do cap friends-feeds, spots, areas, etc.
- how do we rebuild a timeline completely?
- how do we delete a...
  - ...friendship: scan through the user's followers' friends-feeds and delete any TimelineEvents for the user (!)
  - ...user: scan/delete timeline events from user's followers friends-feeds, user's feed, all spots (!), all trips, etc.... eesh.
    - or, just delete the user and all their TimelineEvents, and deal with the orphaned pointers on read
  - ...spot
  - ...checkin
  - ...trip
  - ...highlight (aka re-placed highlight)
  - deleting an event deletes it and removes it from all its timelines
  - deleting a subscription removes all events from the right timelines
  - would deleting stuff get easier if we used predictable keys?
  - event should keep track of which timelines it's added to, for easy deleting later?
