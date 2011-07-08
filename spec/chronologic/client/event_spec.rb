require 'spec_helper'
require 'story'

describe Chronologic::Client::Event do

  let(:story) { Story.new }
  let(:event) do
    {
      'key' => 'story_1',
      'data' => {
        'title' => 'Some awesome story is awesome.'
      },
      'timestamp' => Time.now,
      'objects' => {
      'users' => {
      'user_1' => {'username' => 'akk', 'age' => '31'},
      'user_2' => {'username' => 'cmk', 'age' => '30'}
    }
    },
      'subevents' => {
      'photo_1' => {'type' => 'photo', 'message' => 'Look at this!', 'url' => '/p/123.jpg', 'timestamp' => Time.now - 60},
      'photo_2' => {'type' => 'photo', 'message' => 'Look at that!', 'url' => '/p/456.jpg', 'timestamp' => Time.now - 120}
    }
    }
  end


  # ---- SUGAR ----

  context '.attribute' do

    it 'defines an accessor' do
      story.title.should be_nil
    end

    it 'defines a setter' do
      story.title = 'Great party!'
      story.title.should eq('Great party!')
    end

    it 'tracks dirtiness for attributes' do
      story.should_not be_changed
      story.title = 'Great party!'
      story.title_changed?.should be_true
      story.should be_changed
    end

    it 'generates an attributes hash' do
      story.title = "It's a story!"
      story.cl_attributes.should eq(:title => "It's a story!")
    end
  end

  context '.objects' do

    it 'defines a collection append method' do
      user = Story::User.new
      story.add_user(user)
      story.users.should include(user)
    end

    it 'defines a collection remove method' do
      user = Story::User.new
      story.add_user(user)
      story.remove_user(user)
      story.users.should be_empty
    end

    it 'defines a collection accessor' do
      story.users.should eq([])
    end

    it 'converts loaded objects to the proper class' do
      story = Story.new.from(event)
      story.users.first.should be_kind_of(Story::User)
    end

    it 'fetches objects in order defined by the class' do
      story = Story.new.from(event)
      story.users.first.username.should eq('cmk')
      story.users.last.username.should eq('akk')
    end

    it 'generates a hash for saving to Chronologic' do
      user = Story::User.new
      story.add_user(user)
      story.cl_objects.should eq({"users" => ["user_1"]})
    end

  end

  context '.events' do

    it 'defines a collection append method' do
      event = Story::Photo.new
      story.add_activity(event)
      story.activities.should include(event)
    end

    it 'defines a collection remove method' do
      event = Story::Photo.new
      story.add_activity(event)
      story.remove_activity(event)
      story.activities.should be_empty
    end

    it 'defines a collection accessor' do
      story.activities.should eq([])
    end

    it 'converts loaded events to the appropriate class' do
      story = Story.new.from(event)
      story.activities.first.should be_kind_of(Story::Photo)
    end

    it 'fetches events in order defined by the class' do
      story = Story.new.from(event)
      story.activities.first.url.should match(/456\.jpg/)
      story.activities.last.url.should match(/123\.jpg/)
    end

    it 'generates an array for saving to Chronologic' do
      event = Story::Photo.new
      story.add_activity(event)
      story.cl_subevents.should eq(['photo_1'])
    end
  end

  it "has a timestamp" do
    t = Time.now
    story.timestamp = t
    story.timestamp.should eq(t)
  end

  it 'instantiates a new event object' do
    story.title.should be_nil
    story.should be_new_record
  end

  it 'tracks timelines' do
    story.timelines = ['user_1', 'spot_1']
    story.timelines.should eq(['user_1', 'spot_1'])
  end

  context '#from' do

    before { story.from(event) }

    it 'initializes an event from a hash' do
      story.title.should eq('Some awesome story is awesome.')
    end

    it 'clears the new_record? flag' do
      story.should_not be_new_record
    end

    it 'loads objects' do
      story.objects['user_1'].should eq(event['objects']['user_1'])
    end

    it 'loads events' do
      story.events['photo_1'].should eq(event['subevents']['photo_1'])
    end

    it "loads the event key" do
      story.cl_key.should eq(event['key'])
    end

    it "loads the timestamp" do
      story.timestamp.to_s.should eq(event['timestamp'].to_s)
    end

  end

  # ---- CRUD ----

  context '.fetch' do

    it 'loads an existing event' do
      title = 'This is a great story!'

      story.client = double
      story.client.should_receive(:fetch).and_return('data' => {'title' => title})

      story = Story.fetch('story_123')
      story.title.should == title
    end

  end

  context '#save' do

    before { story.client = stub }
    before { story.title = 'This is a great thing.' }

    it 'publishes new events' do
      story.client.should_receive(:publish)
      story.save
    end

    it 'updates existing events' do
      story.client.should_receive(:update)
      story.new_record = false
      story.save
    end

  end

  context '#destroy' do

    it 'does not attempt to unpublish a new record' do
      expect { story.destroy }.to raise_exception
    end

    it 'unpublishes an event' do
      story.new_record = false
      story.client.should_receive(:unpublish)
      story.destroy
    end

  end

  # ---- INTERNALS ----

  it 'has a Chronologic key' do
    story.cl_key = 'story_1' # SLIME
    story.cl_key.should eq('story_1')
  end

  it 'compares to other objects' do
    left = story.from(event)
    right = 'not a story'
    left.should_not eq(right)
  end

  it 'compares to another event object' do
    left = story.from(event)
    right = Story.new.from(event)
    left.should eq(right)

    left.title = 'Something else...'
    left.should_not eq(right)
  end

end
