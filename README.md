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
updates, and view a timeline of all statuses in reverse-chronological order. First you'll
create some _events_:

	# Create a connection
	require 'chronologic'
    chronologic = Chronologic::Connection.new

	# Scott and Josh update their status
    chronologic.event(:status_1, :data => {:username => 'sco', :status => 'This is Scott.'})
    chronologic.event(:status_2, :data => {:username => 'jw',  :status => 'This is Josh.'})

	# Get all the events in the timeline
	chronologic.timeline[:events]
	=> [{:username => 'jw', :status=>'This is Josh.'}, {:username => 'sco', :status=>'This is Scott.'}]

Note that the keys in the `:data` hash are arbitrary, but all the values must be strings.
There is no assumption that you'll store Twitter-like status updates; maybe your application
calls for something more like this:

    { :actor => "sco", :verb => "joined_group", :object => "Rubyists", :created_at => "2010-07-22 18:12:30" }

### Timelines

Next you'll want to view all of the events from a given user. To do that, assign events
to any number of _timelines_:

    # Create events and add them to some timelines
    chronologic.event(:status_1, :timelines => [:sco], :data => {:username => 'sco', :status => 'This is Scott.'})
    chronologic.event(:status_2, :timelines => [:jw],  :data => {:username => 'jw',  :status => 'This is Josh.'})

    # Get a timeline by name
    chronologic.timeline(:sco)[:events]
	=> [{:username => 'sco', :status=>'This is Scott.'}]

### Subscriptions

Next you want to follow a bunch of users, and see their activity aggregated. You *could*
do this aggregation on demand: fetch a bunch of users' timelines, and merge them all together.
But that's a lot of wasted effort, and could be slow if you follow thousands of people. You
could also do the fan-out on write: look up a user's followers, and adding each of them to
the :timelines array. But what happens when the user gets a new follower? Or loses one? To
help with these scenarios, use _subscriptions_:

	# Scott follows Josh and Keegan
    chronologic.subscribe(:sco_friends, :jw)
    chronologic.subscribe(:sco_friends, :keeg)

	# Josh and Keegan update, pushing their events to their subscribers
    chronologic.event(:status_2, :subscribers => [:jw],   :data => {:username => 'jw',   :status => 'This is Josh.'})
    chronologic.event(:status_3, :subscribers => [:keeg], :data => {:username => 'keeg', :status => 'This is Keegan.'})

	# Get aggregated activity from Scott's friends
	chronologic.timeline(:sco_friends)[:events]
	=> [{:username => 'keeg', :status=>"This is Keegan."}, {:username => 'jw', :status=>"This is Josh."}]

Note that subscriptions are useful for more than just a social graph. You might also use
them to provide aggregated activity for all members of a group, disparate activity around
a common object, etc. Unsubscribing will cause all of the appropriate events to be removed
from the appropriate timelines.

### Objects

To display a complete activity feed, you'll probably need the user's name, image URL,
and some other metadata. You could store that stuff right in the event, but that creates
a lot of duplicated storage, making it difficult to deal with changes. To address
these issues, use _objects_:

    # Store a metadata object for each user (any time they're created or changed)
    chronologic.object(:keeg, {:username => 'keeg',  :name => 'Keegan Jones'})

	# When creating an event, include references to any object it relies on
    chronologic.event(:status_3, :objects => {:user => :keeg}, :timelines => [:keeg], :data => {:status => 'This is Keegan.'})

	# When the event is returned in a timeline, the associated objects' metadata will be included
	chronologic.timeline(:keeg)[:events]
	=> [{:status => "This is Keegan.", :user => {:username => 'keeg', :name => 'Keegan Jones'}}]

Objects are appropriate for any data that's needed to represent a complete feed, but
that's not intrinsic to the event itself. Deleting an object will cause all of the events
it depends on to be deleted.

### Sub-events

Some events aren't directly part of a timeline, but attached another event -- like
a comment on a post. Do that with the _:events_ option:

	# To create a child, reference the parent event key
    chronologic.event(:events => [:status_3], :data => {:status => 'Hi, Keegan!'})

An event can both a sub-event, *and* added to a timeline -- e.g., attach a comment
to a post, and send a notification to the creator of the post.


Implementation, Performance & Scalability
-----------------------------------------

All of the data is stored in Cassandra, which provides high availability, high write
performance, and automatic partitioning of data across multiple nodes. So even with tons
of users and tons of messages, it'll still be pretty fast to get the recent events for
each user.

TODO: more detail about how the storage works, benchmarks, idempotence, Pull on Demand
vs. Push on Change model


Installation & Configuration
----------------------------

Install chronologic:

    sudo gem install chronologic

Edit conf/storage-conf.xml to define the keyspace:

    <Keyspace Name="Chronologic">
      <ColumnFamily Name="Object" CompareWith="UTF8Type" />
      <ColumnFamily Name="Subscription" CompareWith="UTF8Type" />
      <ColumnFamily Name="Event" CompareWith="UTF8Type" />
      <ColumnFamily Name="Timeline" CompareWith="UTF8Type" />

      <ReplicaPlacementStrategy>org.apache.cassandra.locator.RackUnawareStrategy</ReplicaPlacementStrategy>
      <ReplicationFactor>1</ReplicationFactor>
      <EndPointSnitch>org.apache.cassandra.locator.EndPointSnitch</EndPointSnitch>
    </Keyspace>

...or conf/cassandra.yml:

- name: Chronologic
  replica_placement_strategy: org.apache.cassandra.locator.RackUnawareStrategy
  replication_factor: 1
  column_families:
    - name: Object
      compare_with: UTF8Type

    - name: Subscription
      compare_with: UTF8Type

    - name: Event
      compare_with: UTF8Type

    - name: Timeline
      compare_with: UTF8Type

The RandomPartitioner should be used.

Start cassandra:
    sudo rm -rf /var/log/cassandra
    sudo rm -rf /var/lib/cassandra
    sudo mkdir -p /var/log/cassandra
    sudo chown -R `whoami` /var/log/cassandra
    sudo mkdir -p /var/lib/cassandra
    sudo chown -R `whoami` /var/lib/cassandra
    export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home
    export PATH=$JAVA_HOME/bin:$PATH
    bin/cassandra -f

Start server:
    rackup


### As a Rails plugin:

Edit your Gemfile:

    gem "chronologic", :require_as => ["chronologic", "chronologic/railtie"]


Examples
--------

See the `examples` directory.


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
- PSHB
  - the app requests notification when a timeline changes, and fires the hub notification then
  - not efficient: it'd be better if we could ping the hub with all the changes at once (user, spot, area, all friends, etc)
  - maybe you can tell Chronologic which timelines should cause hub pings and let it manage them
  - or maybe chronologic itself should provide hub functionality
- APS notifications (outside of scope?)
- websockets notifications (outside of scope?)
- server should catch exceptions and return error codes

- evented-sinatra ruby server? (could use evented cassandra)
- test with millions of objects/events/subscriptions
- etag/if-modified-since
- consider storing full copies of events in timelines, so that reads don't require joins/multigets
- document how to build a new timeline or re-build one
- consider making a Timeline class, to help with pagination etc
- document creating atom/activitystreams feeds
- web UI
  - stats
  - display a list of all timelines (or just recently changed ones)
  - add-object form
  - add-subscription form
  - add-event form (with dropdowns for all timelines, objects, events, etc)
- redis for real-time notifications and queuing?
- client-side memcached
  - store etag or last-mod values, and response body, so server can say not-modified
  - also consider supporting short Expires headers
- server-side memcached
  - when a timeline changes, preemptively cache it, so that even cold requests are fast
  - could still use a TTL so that feeds timelines that are never requested and never change don't eat up space
  - or get fancy, and try to prioritize timelines that are frequently requested
- create github site
- add rdoc comments
- privacy: does a checkin get published to the spot feed even if the user is private? if I look at a spot feed, shouldn't I see my private friends?
  - perhaps the event should have a private flag, so it can be excluded from results if there's not a subscription between the requester and the event creator
- allow timelines to be (optionally) capped, and to remove parentless events that are no longer represented in a timeline
- ensure adding a subscription adds events to the right timelines
- enforce the requirement that :data values be keys
- document how to run on heroku (is there any hosted cassandra?)
- support retries and falling back to another node
- recommend using the HTTP interface, or directly through Chronologic::Connection?
- document rails-specific idioms (how to config, use observers to create events)
- document how to create a top-news feed
- get some specs running
- document/streamline cassandra installation
- node-based server
- avro or some other interface?
- any need for a broadcast system like zeromq?
- mongo backend?
- riak backend?
- enqueue fanout? or will it be fast enough? what if cassandra is temporarily down?
  - even though writes are fast, maybe they should still be triggered by a queue, so that we can group together notifications, publishing, etc., and pause cassandra sometimes.
- event clustering? (so your friends-feed can't be overrun by one hyper checker-inner). probably out of scope.
- when/why should key be UUIDs?
- set up gem
- consider that testing for key existence is very fast
