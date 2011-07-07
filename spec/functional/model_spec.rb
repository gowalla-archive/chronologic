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

  it 'create a new record' do
    url = story.save
    event = schema.event_for(story.cl_key)
    event.should_not be_nil
    JSON.load(event['data'])['title'].should eq(story.title)
    event['timestamp'].should eq(story.timestamp.iso8601)
  end

  it 'fetch a new record'

  it 'update a story'

  it 'delete a story'

  it' change objects on a story'

  it 'change events on a story'

  it 'create an object'

  it 'fetch an object'

  it 'update an object'

  it 'delete an object'

  it 'clear an object attribute'

end
