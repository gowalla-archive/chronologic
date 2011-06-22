require 'spec_helper'

describe Chronologic::Client::Event do

  class Story
    class User
      attr_accessor :username, :age

      def to_cl_key
        'user_1'
      end

      def from_cl(attrs)
        self.username = attrs['username']
        self.age = attrs['age']
        self
      end

      def <=>(other)
        self.age <=> other.age
      end
    end

    class Activity
      def from_cl(attrs)
        case attrs['type']
        when 'photo'
          Photo.new.from_cl(attrs)
        when 'comment'
          Comment.new.from_cl(attrs)
        end
      end
    end

    class Photo < Activity
      attr_accessor :message, :url, :timestamp

      def to_cl_key
        'photo_1'
      end

      def from_cl(attrs)
        self.message = attrs['message']
        self.url = attrs['url']
        self.timestamp = attrs['timestamp']
        self
      end

      def <=>(other)
        self.timestamp <=> other.timestamp
      end
    end

    include Chronologic::Client::Event

    attribute :title

    objects :users, User
    events :activities, Activity
  end

  let(:story) { Story.new }
  let(:event) do
    {
      'data' => {
        'title' => 'Some awesome story is awesome.'
      },
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

  end

  # ---- CRUD ----

  it 'instantiates a new event object' do
    story.title.should be_nil
    story.should be_new_record
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

  end

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

end

