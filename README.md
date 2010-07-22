Chronologic: activity feeds as a service
========================================

Chronologic is a library for managing activity feeds (aka news feeds or timelines), 
like Twitter, or just about any social network. It uses Cassandra. It's meant to be
easy to scale, be we shall see.


Overview
--------

# Events

Suppose you want to create a new social network with the requisite activity stream,
so that users can see what their friends are up to. You start simple: users can create
status updates, and view a timeline of all statuses, in reverse-chronological order.

	# Create a connection
	require 'chronologic'
    chronologic = Chronologic::Connection.new

	# Scott and Josh update their status (the structure of the :info hash is arbitrary)
    chronologic.event(:info => { :username => 'sco', :status => 'This is Scott.' })
    chronologic.event(:info => { :username => 'jw',  :status => 'This is Josh.' })

	# Get all events
	chronologic.global_timeline
	=> [{:username => 'jw', :status=>'This is Josh.'}, {:username => 'sco', :status=>'This is Scott.'}]

# Timelines

Okay, but you also need to be able to view all of the events from one user. To enable that,
specify timeline(s) when you create an event.

    # Add events and push them to specific timelines
    chronologic.event(:timelines => [:sco], :info => { :username => 'sco', :status => 'This is Scott.' })
    chronologic.event(:timelines => [:jw],  :info => { :username => 'jw',  :status => 'This is Josh.' })

    # Get a timeline by name
    chronologic.timeline(:sco)
	=> [{:username => 'sco', :status=>'This is Scott.'}]

# Subscriptions

Simple enough. But you don't want to look at just one user's activity at a time -- you want to
follow a bunch of users, and see their activity aggregated. To do that, create some _subscriptions_:

	# Scott follows Josh and Keegan
    chronologic.subscribe(:sco_friends, :jw)
    chronologic.subscribe(:sco_friends, :keeg)

	# Josh and Keegan update, pushing their events to their subscribers
    chronologic.event(:subscribers => [:jw],   :timelines => [:jw],   :info => { :username => 'jw',   :status => 'This is Josh.' })
    chronologic.event(:subscribers => [:keeg], :timelines => [:keeg], :info => { :username => 'keeg', :status => 'This is Keegan.' })

	# Get aggregated activity from Scott's friends
	chronologic.timeline(:sco_friends)
	=> [{ :username => 'keeg', :status=>"This is Keegan." }, { :username => 'jw', :status=>"This is Josh." }]

# Objects

To display a complete activity feed, you'll probably want the user's name, image URL, etc. You
could store that data right in the event, but that's a lot of duplicated storage. And what happens
if the user changes their name? To address these issues, you'll want to use _objects_.

    # Cache a metadata object for each user (any time they're created or changed)
    chronologic.object(:keeg, { :username => 'keeg',  :name => 'Keegan Jones' })

	# When creating an event, include references to any object it relies on
    chronologic.event(:objects => { :user => :keeg }, :subscribers => [:keeg], :timelines => [:keeg], :info => { :status => 'This is Keegan.' })

	# When the event is retrieved, the associated object's metadata will be included
	chronologic.timeline(:sco_friends)
	=> [{ :status => "This is Keegan.", :user => { :username => 'keeg', :name => 'Keegan Jones' }}]

# Child events

Sometimes you want to attach one event to another -- for example, a comment on a post --
but it's not directly attached to any timeline. Just use the :events option.

    # When creating an event, use the :key option to override the default UUID key
    chronologic.event(:key => "status_1", :info => { :status => 'This is Keegan.' })

	# To create a child, reference the parent event key
    chronologic.event(:events => [:status_1], :info => { :status => 'Hi, Keegan!' })

# Mixing event types

Say you want to get crazy and include more than just statues in a timeline. Cassandra is
schemaless, so the structure of objects and event-info hashes is up to you. Just add a
:type property or something to help you distinguish event types.

    chronologic.event(:timelines => [:sco], :info => { :type => 'ad', :status => 'This is a message from our sponsor...' })

What happens if a user deletes an event? Or un-follows a friend?

    # TODO


Performance & Scalability
-------------------------

All of the information is stored in Cassandra, which provides high availability, high write
performance, and automatic partitioning of data across multiple nodes. So even with tons of
users and tons of messages, it'll still be pretty fast to get the recent events for each user.


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
- maybe go back to the underscore-prefixed special event attributes, so that we can ditch the info hash?
- rename 'subscribers' option to 'topics'?
- child events
- web UI
- get some specs running
- set up gem
- document/streamline cassandra installation
- app should keep its own stats
- redis for real-time notifications?
- recommend using the HTTP interface, or directly through Chronologic::Connection?
- enqueue fanout? or will it be fast enough? what if cassandra is temporarily down?
  - even though writes are fast, maybe they should still be triggered by a queue, so that we can group together notifications, publishing, etc., and pause cassandra sometimes.
- this system won't help scale the checkins, itemevents, etc tables. but it should help us read from them less.
- store pins, highlights, etc
- etag/if-modified-since etc?
- can this system become the basis for the PSHB feeds, the notifications system (APS and atom-based), and the real-time web notifications?
- how do we tell the system that some timelines should be capped, and some should be infinite?
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
