# Chronologic: activity feeds as a service.

# edit conf/storage-conf.xml to define keyspace:
  <Keyspace Name="Chronologic">
    <ColumnFamily CompareWith="UTF8Type" Name="Objects" />
    <ColumnFamily CompareWith="UTF8Type" Name="Subscriptions" ColumnType="Super" CompareSubcolumnsWith="TimeUUIDType" />
    <ColumnFamily CompareWith="UTF8Type" Name="Events" /><!-- compare with time? -->
    <ColumnFamily CompareWith="UTF8Type" Name="Timelines" ColumnType="Super" CompareSubcolumnsWith="TimeUUIDType" />
    
    <ReplicaPlacementStrategy>org.apache.cassandra.locator.RackUnawareStrategy</ReplicaPlacementStrategy>
    <ReplicationFactor>1</ReplicationFactor>
    <EndPointSnitch>org.apache.cassandra.locator.EndPointSnitch</EndPointSnitch>
  </Keyspace>

# start cassandra
  cd ~/Desktop/apache-cassandra-0.6.3/
  export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home
  export PATH=$JAVA_HOME/bin:$PATH
  bin/cassandra -f

# start server
  shotgun


$LOAD_PATH.unshift 'lib'
require 'chronologic'
db = Cassandra.new('Chronologic')
db.clear_keyspace!
c = Chronologic::Connection.new(db)
c.insert_object(:user_1, {'username' => 'sco'})
c.insert_object(:user_2, {'username' => 'jw'})
c.get_object(:user_1)
c.insert_subscription(:user_2_friends, :user_1)
c.get_subscribers(:user_1)
c.insert_event({'type' => 'checkin', 'id' => '1', 'message' => 'Hello'}, :timelines => [:user_1, :spot_1], :subscribers => [:user_1])
c.get_timeline(:user_2_friends)


# TODO
- integrate objects into get_timeline
- sub-events
- get some specs running
- set up repo/gem
- link to cassandra-gem tasks for installing cassandra
- use it through the HTTP interface, or directly through Chronologic::Connection?
  - HTTP lets us scale it separately from the rest of the app, re-write the storage bits as needed
    (cassandra, friendly, redis, mongo, neo4j, memcached?), or re-write the server as needed (node, scala?),
    use memcached/redis for performance, if needed
  - direct is faster
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
