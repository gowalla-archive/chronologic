require 'functional_helper'

describe "Chronologic API uses cases" do

  it "publish an event with subevents, remove the event and subevents, get a blank timeline" do
    event = simple_event
    comment0 = Chronologic::Event.new(
      'key' => 'comment_1',
      'data' => {'type' => 'comment', 'message' => 'Me too!', 'parent' => 'checkin_1'},
      'objects' => {'user' => 'user_2'},
      'timelines' => ['checkin_1']
    )
    event.timelines << 'user_2' # Add a timeline to the parent event

    connection.publish(comment0)
    connection.publish(event)

    comment1 = Chronologic::Event.new(
      'key' => 'comment_2',
      'data' => {'type' => 'comment', 'message' => 'Me three!', 'parent' => 'checkin_1'},
      'objects' => {'user' => 'user_3'},
      'timelines' => ['checkin_1']
    )
    connection.publish(comment1)

    event.timelines << 'user_3'
    connection.update(event)

    connection.unpublish('comment_2')
    event.timelines.delete('user_3')
    connection.update(event)

    connection.unpublish('comment_1')
    event.timelines.delete('user_2')
    connection.update(event)

    connection.unpublish(event.key)
    connection.timeline(event.timelines.first)["feed"].should be_empty
  end

  it "publish an event with a forced timestamp so it appears in the right position" do
    old_event = simple_event.merge(
      "key" => 'event_2',
      "data" => {'message' => 'This appears last'}
    )

    new_event = simple_event.merge(
      "key" => 'event_1',
      "data" => {'message' => 'This appears first'}
    )

    connection.publish(new_event)
    connection.publish(old_event, true, Time.now.tv_sec - 60)

    feed = connection.timeline(old_event.timelines.first)
    feed["items"].first.key.should eq(new_event.key)
    feed["items"].last.key.should eq(old_event.key)
  end

end

