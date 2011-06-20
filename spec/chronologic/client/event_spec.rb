require 'spec_helper'

describe Chronologic::Client::Event do

  class Story
    include Chronologic::Client::Event

    attribute :title
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
    
    it 'defines a collection append method'

    it 'defines a collection remove method'

    it 'defines a collection accessor'

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

    before { story.from({'title' => 'Some awesome story is awesome.'}) }

    it 'initializes an event from a hash' do
      story.title.should eq('Some awesome story is awesome.')
    end

    it 'clears the new_record? flag' do
      story.should_not be_new_record
    end

  end

  context '.fetch' do

    it 'loads an existing event' do
      title = 'This is a great story!'

      story.client = double
      story.client.should_receive(:fetch).and_return({'title' => title})

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

