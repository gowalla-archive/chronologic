# Cassandra: you put your activity in it

* Subscribe to activity on an entity (user, spot, region, etc.)
* Publish events to one or more entities
* Fetch events from an entity

## The basic idea.

record/unrecord - create/remove users/spots/regions/etc.
subscribe/unsubscribe - connect an entity to another timeline
publish/unpublish - create or remove events from a timeline

## How it works

Publishing a new event: store the event, look up subscribers, write to event
timelines and subscriber timelines

Publishing a subevent: store the event including the parent event as a timeline

Fetch a timeline: fetch event UUIDs, fetch actual events, fetch subevents,
fetch objects for all events
