Chronologic: activity feeds as a service
========================================

Chronologic is a library for managing activity feeds (aka news feeds or timelines), like
Twitter, or just about any social network. It uses Cassandra. It's meant to be easy to
scale, be we shall see.


Overview
--------

### Events

Suppose you want to create a new social network, with the requisite activity stream, so
that users can see what their friends are up to. You start simple: users can create status
updates, and view a timeline of all statuses in reverse-chronological order. Just create
some _events_:

	# Create a connection
	require 'chronologic'
    chronologic = Chronologic::Connection.new

	# Scott and Josh update their status
    chronologic.event(:status_1, :data => {:username => 'sco', :status => 'This is Scott.'})
    chronologic.event(:status_2, :data => {:username => 'jw',  :status => 'This is Josh.'})

	# Get all the events in the special global timeline
	chronologic.timeline(:_global)
	=> [{:username => 'jw', :status=>'This is Josh.'}, {:username => 'sco', :status=>'This is Scott.'}]

Note that the contents of the `:data` hash is arbitrary (except that all the values should
be strings). There is no assumption that you'll store Twitter-like status updates; maybe
your application calls for something more like this:

    { :actor => "sco", :verb => "joined_group", :object => "Rubyists", :created_at => "2010-07-22 18:12:30" }

### Timelines

You'll also want to view all of the events from a given user. To allow that, create events
with associated _timeline(s)_:

    # Create events and add them to some timelines
    chronologic.event(:status_1, :timelines => [:sco], :data => {:username => 'sco', :status => 'This is Scott.'})
    chronologic.event(:status_2, :timelines => [:jw],  :data => {:username => 'jw',  :status => 'This is Josh.'})

    # Get a timeline by name
    chronologic.timeline(:sco)
	=> [{:username => 'sco', :status=>'This is Scott.'}]

### Subscriptions

Now, you want to follow a bunch of users, and see their activity aggregated. You could
handle this by looking up a user's followers, and adding each of them to the :timelines
array. But what happens when the user gets a new follower? Or loses one? To help with
these scenarios, use _subscriptions_:

	# Scott follows Josh and Keegan
    chronologic.subscribe(:sco_friends, :jw)
    chronologic.subscribe(:sco_friends, :keeg)

	# Josh and Keegan update, pushing their events to their subscribers
    chronologic.event(:status_2, :subscribers => [:jw],   :data => {:username => 'jw',   :status => 'This is Josh.'})
    chronologic.event(:status_3, :subscribers => [:keeg], :data => {:username => 'keeg', :status => 'This is Keegan.'})

	# Get aggregated activity from Scott's friends
	chronologic.timeline(:sco_friends)
	=> [{:username => 'keeg', :status=>"This is Keegan."}, {:username => 'jw', :status=>"This is Josh."}]

Note that subscriptions are useful for more than just a social graph. You might also use
them to provide aggregated activity for all members of a group, etc. Unsubscribing
will cause all of the appropriate events to be removed from the appropriate timelines.

### Objects

To display a complete activity feed, you'll probably want the user's name, image URL,
and some other metadata. You could store that stuff right in the event, but that creates
a lot of duplicated storage. And what happens if the user changes their name? To address
these issues, you'll want to use _objects_:

    # Store a metadata object for each user (any time they're created or changed)
    chronologic.object(:keeg, {:username => 'keeg',  :name => 'Keegan Jones'})

	# When creating an event, include references to any object it relies on
    chronologic.event(:status_3, :objects => {:user => :keeg}, :timelines => [:keeg], :data => {:status => 'This is Keegan.'})

	# When the event is returned in a timeline, the associated objects' metadata will be included
	chronologic.timeline(:keeg)
	=> [{:status => "This is Keegan.", :user => {:username => 'keeg', :name => 'Keegan Jones'}}]

Objects are appropriate for any data that's needed to represent a complete feed, but
that's not intrinsic to the event itself. Deleting an object will cause all of the events
it depends on to be deleted.

### Sub-events

Some events shouldn't be directly part of a timeline, but attached another event -- like
a comment on a post. Do that with the _:events_ option:

	# To create a child, reference the parent event key
    chronologic.event(:events => [:status_3], :data => {:status => 'Hi, Keegan!'})

You may also create an event that's both a sub-event, *and* added to a timeline -- e.g.,
attach a comment to a post, and send a notification to the creator of the post.


Implementation, Performance & Scalability
-----------------------------------------

All of the data is stored in Cassandra, which provides high availability, high write
performance, and automatic partitioning of data across multiple nodes. So even with tons
of users and tons of messages, it'll still be pretty fast to get the recent events for
each user.

[Pull on Demand model, vs. Push on Change model]

TODO: more detail about how the storage works, benchmarks


Installation & Configuration
----------------------------

Install chronologic:

    sudo gem install chronologic

Edit conf/storage-conf.xml to define the keyspace:

    <Keyspace Name="Chronologic">
      <ColumnFamily Name="Object" CompareWith="UTF8Type" /><!-- BytesType? -->
      <ColumnFamily Name="Subscription" CompareWith="UTF8Type" /><!-- BytesType? -->
      <ColumnFamily Name="Event" ColumnType="Super" CompareWith="UTF8Type" CompareSubcolumnsWith="UTF8Type" />
      <ColumnFamily Name="Timeline" CompareWith="TimeUUIDType" /><!-- Bytes? -->

      <ReplicaPlacementStrategy>org.apache.cassandra.locator.RackUnawareStrategy</ReplicaPlacementStrategy>
      <ReplicationFactor>1</ReplicationFactor>
      <EndPointSnitch>org.apache.cassandra.locator.EndPointSnitch</EndPointSnitch>
    </Keyspace>

The RandomPartitioner should be used.

Start cassandra:
    cd ~/Desktop/apache-cassandra-0.6.3/
    export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home
    export PATH=$JAVA_HOME/bin:$PATH
    bin/cassandra -f

Start server:
    shotgun


Examples
--------

See the +examples+ directory.


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
- store timestamps with everything
- also a good idea to make event-ids in timelines key names, not values, so that inserts are idempotent (then how are they sorted? prepend timestamp?)
- speed up ruby client: persistent connections, yajl, etc
- re-write server/connection in node
- web UI
- redis for real-time notifications and queuing?
- memcached for caching responses
- support for re-building a timeline
- etag/if-modified-since etc

- privacy: does a checkin get published to the spot feed even if the user is private? if I look at a spot feed, shouldn't I see my private friends?
  - perhaps the event should have a private flag, so it can be excluded from results if there's not a subscription between the requester and the event creator
- can this system become the basis for the PSHB feeds, the notifications system (APS and atom-based), and the real-time web notifications?
- allow timelines to be (optionally) capped, and to remove parentless events that are no longer represented in a timeline
- ensure adding a subscription adds events to the right timelines
- enforce the requirement that :data values be keys
- document how to run on heroku (is there any hosted cassandra?)
- support retries and falling back to another node
- recommend using the HTTP interface, or directly through Chronologic::Connection?
- note: all updates should be idempotent (so they can handle retries. so maybe require the :key option on #event)
- consider storing full copies of events in timelines, so that reads don't require joins (multigets)
- document rails-specific idioms (how to config, use observers to create events)
- document how to create a top-news feed
- get some specs running
- document/streamline cassandra installation
- stats (?)
- enqueue fanout? or will it be fast enough? what if cassandra is temporarily down?
  - even though writes are fast, maybe they should still be triggered by a queue, so that we can group together notifications, publishing, etc., and pause cassandra sometimes.
- event clustering? (so your friends-feed can't be overrun by one hyper checker-inner). probably out of scope.
- when/why should key be UUIDs?
- set up gem
- consider that testing for key existence is very fast
