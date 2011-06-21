require 'spec_helper'

describe Chronologic::Client::Event do

  class Story
    class User
      def to_cl_key
        'user_1'
      end
    end

    include Chronologic::Client::Event

    attribute :title

    objects :users, User
  end

  let(:story) { Story.new }

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

  end

  context '.events' do

    it 'defines a collection append method'

    it 'defines a collection remove method'

    it 'defines a collection accessor'

  end

  # ---- CRUD ----

  it 'instantiates a new event object' do
    story.title.should be_nil
    story.should be_new_record
  end

  context '#from' do

    let(:event) do
      {
        'data' => {
          'title' => 'Some awesome story is awesome.'
        },
        'objects' => {
          'user_1' => {'username' => 'akk', 'age' => '31'}
        }
      }
    end

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

