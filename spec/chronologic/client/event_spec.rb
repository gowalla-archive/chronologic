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
      'objects' => {
        'users' => {
          'user_1' => {'username' => 'akk', 'age' => '31'},
          'user_2' => {'username' => 'cmk', 'age' => '30'}
        }
      },
      'timelines' => ['user_1', 'spot_1'],
      'subevents' => [
        {'key' => 'photo_1', 'type' => 'photo', 'message' => 'Look at this!'},
        {'key' => 'photo_2', 'type' => 'photo', 'message' => 'Look at that!'}
      ]
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
      story.should_not be_cl_changed
      story.title = 'Great party!'
      story.should be_cl_changed
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
      story.activities.first.message.should match(/that/)
      story.activities.last.message.should match(/this/)
    end

    it 'generates an array for saving to Chronologic' do
      event = Story::Photo.new
      story.add_activity(event)
      story.cl_subevents.should eq(['photo_1'])
    end
  end

  it 'instantiates a new event object' do
    story.title.should be_nil
    story.should be_new_record
  end

  context '#add_timeline' do

    before { story.add_timeline('user_1') }

    it 'adds a timeline to the event' do
      story.timelines.should eq(['user_1'])
    end

    it 'sets the dirty timelines flag' do
      story.should be_dirty_timelines
    end

  end

  context '#remove_timeline' do

    before { story.from('timelines' => ['user_1']) }

    it 'removes a timeline from the event' do
      story.remove_timeline('user_1')
      story.timelines.should eq([])
    end

    it 'sets the dirty timelines flag' do
      story.remove_timeline('user_1')
      story.should be_dirty_timelines
    end

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
      story.events['photo_1'].should eq(event['subevents'].first)
    end

    it "loads the event key" do
      story.cl_key.should eq(event['key'])
    end

    it "loads the timelines" do
      story.timelines.should eq(['user_1', 'spot_1'])
    end

  end

  # ---- CRUD ----

  context '.fetch' do

    it 'loads an existing event' do
      title = 'This is a great story!'

      connection = double
      connection.should_receive(:fetch).and_return('data' => {'title' => title})
      Chronologic::Client::Connection.instance = connection

      story = Story.fetch('story_123')
      story.title.should == title
    end

    it "raises an exception if no event was found" do
      connection = double(:fetch => nil)
      Chronologic::Client::Connection.instance = connection

      expect { Story.fetch('story_123') }.to raise_exception
    end

  end

  context '#save' do

    before { connection = Chronologic::Client::Connection.instance = stub }
    before { story.title = 'This is a great thing.' }

    let(:connection) { Chronologic::Client::Connection.instance }

    it 'publishes new events' do
      story.connection.should_receive(:publish)
      story.save
    end

    it 'updates existing events' do
      story.connection.should_receive(:update)
      story.new_record = false
      story.save
    end

    it 'clears the new_record? flag' do
      story.connection.stub(:publish)
      story.save
      story.should_not be_new_record
    end

    it "doesn't save if the event hasn't changed" do
      story = Story.new
      story.save.should be_false
    end

  end

  context '#update' do

    it "delegates updates to the connection" do
      story.connection.should_receive(:update)
      story.update
    end

  end

  context '#destroy' do

    it 'does not attempt to unpublish a new record' do
      expect { story.destroy }.to raise_exception
    end

    it 'unpublishes an event' do
      story.new_record = false
      story.connection.should_receive(:unpublish)
      story.destroy
    end

  end

  # ---- INTERNALS ----

  it 'has a Chronologic key' do
    story.cl_key = 'story_1' # SLIME
    story.cl_key.should eq('story_1')
  end

  it 'compares to other objects' do
    story = Story.new.from(event)
    other = 'not a story'
    story.should_not eq(other)
  end

  it 'compares to another event object' do
    left = story.from(event)
    right = Story.new.from(event)
    left.should eq(right)

    left.title = 'Something else...'
    left.should_not eq(right)
  end

end
