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
  end

  context '.fetch'

  context '#save'

  context '#update'

  context '#destroy'

  # ---- BLEH ----

  it 'tracks unsaved events' do
    pending('remove this?')
    story.title = 'Honkity honk'
    story.should be_new_record
  end

  it 'updates existing events' do
    pending
    story = Story.from('title' => 'Honkity honk')
    story.should_not be_new_record
  end

  # ??? Write an example for #save
  

  it 'updates an existing event'

  it 'deletes an existing event'

  it 'adds an record references'

  it 'removes a record reference'

  it 'fetches record references'

  it 'adds a subevent'

  it 'removes a subevent'

  it 'fetches all subevents'

  it 'sets its parent event'

  it 'adds a timeline'

  it 'removes a timeline'

end

