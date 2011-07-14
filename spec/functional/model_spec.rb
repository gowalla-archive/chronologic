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

    fetched = Story.fetch(url)
    Story.fetch(url).objects['users'].should include(user.to_cl_key)
  end

  it 'update events on an event'

  it 'delete an event'

  it 'create an object'

  it 'fetch an object'

  it 'update an object'

  it 'delete an object'

  it 'clear an object attribute'

end
