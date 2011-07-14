require 'functional_helper'
require 'story'

describe 'Client-side models' do

  before { story.client = Chronologic::Client::Connection.new('http://localhost:9292') }
  before { Chronologic.connection = Cassandra.new('Chronologic') }

  let(:story) do
    Story.new.tap do |story|
      story.cl_key = 'story_1' # XXX hax
      story.title = "TO BRASKY"
      story.timestamp = Time.now
    end
  end
  let(:schema) { Chronologic::Service::Schema }

  it 'create a new event' do
    url = story.save
    event = schema.event_for(story.cl_key)
    event.should_not be_nil
    JSON.load(event['data'])['title'].should eq(story.title)
    event['timestamp'].should eq(story.timestamp.iso8601)
  end

  it 'fetch a new event' do
    url = story.save
    Story.fetch(url).should eq(story)
  end

  it 'update attributes on an event' do
    url = story.save
    story.title = "BRASKY ONCE ATE AN OX IN ONE BITE"
    story.save

    Story.fetch(url).should eq(story)
  end

  it 'update objects on an event' do
    user = Story::User.new
    user.username = 'akk'
    user.age = 31

    url = story.save
    story.add_user(user)
    story.save

    Story.fetch(url).objects['users'].should include(user.to_cl_key)
  end

  it 'update subevents on an event' do
    pending('Save the photo, not the story')
    photo = Story::Photo.new
    photo.message = "Look at this great square-cropped pic!"
    photo.url = '/photos/1'
    photo.timestamp = Time.now.utc

    url = story.save
    story.add_activity(photo)
    story.save

    Photo.fetch(photo.url).parent.should eq(story)
  end

  it 'update timelines on an event' do
    story.add_timeline('user_1')
    url = story.save

    story.add_timeline('spot_1')
    story.save

    Story.fetch(url).timelines.should eq(['user_1', 'spot_1'])
    schema.timeline_events_for('user_1').values.should include(story.cl_key)
    # Make sure that the event was written to the new timeline?
  end

  it 'delete an event'

  it 'properly loads events and objects'

  it 'create an object'

  it 'fetch an object'

  it 'update an object'

  it 'delete an object'

  it 'clear an object attribute'

end
