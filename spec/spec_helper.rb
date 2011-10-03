require 'chronologic'
require 'webmock/rspec'
require 'cassandra/0.7'
require 'cassandra/mock'
require 'helpers'

MultiJson.engine = :yajl

RSpec.configure do |config|
  config.include(ChronologicHelpers)
  config.include(WebMock::API)

  config.before do
    if ENV['CASSANDRA']
      Chronologic::Service::Schema.write_opts = {
        :consistency => Cassandra::Consistency::ONE
      }
      Chronologic.connection = Cassandra.new(
        'ChronologicTest',
        ['127.0.0.1:9160'],
        :connection_timeout => 3,
        :retries => 2,
        :timeout => 3
      )
      clean_up_keyspace!(Chronologic.connection)
    else
      schema = {
        'ChronologicTest' => {
          'Object' => {},
          'Subscription' => {},
          'Event' => {},
          'Timeline' => {}
        }
      }
      Chronologic.connection = Cassandra::Mock.new('ChronologicTest', schema)
    end
  end

  config.before do
    WebMock.disable_net_connect!
    WebMock.reset!
  end

end

shared_examples "a feed strategy" do

  it "fetches a timeline" do
    length = populate_timeline.length

    subject.create("user_1_home").items.length.should == length
  end

  it "generates a feed and properly handles empty subevents" do
    event = simple_event
    protocol.publish(event)

    feed = subject.create(
      event.timelines.first,
      :fetch_subevents => true
    )
    feed.items.first.subevents.should == []
  end

  it "fetches a feed by page" do
    populate_timeline
    page = subject.create("user_1_home", :per_page => 5).next_page

    subject.create(
      "user_1_home",
      :page => page,
      :per_page => 5
    ).items.length.should ==(5)
  end

  # AKK: it would be great if we didn't have to call feed.items to load
  # the paging bits

  it "tracks the event key for the next page" do
    populate_timeline
    feed = subject.new("user_1_home", 1)
    feed.items

    feed.next_page.should_not be_nil
  end

  it "doesn't set the next page if there is no next page" do
    events = populate_timeline
    feed = subject.new("user_1_home", events.length)
    feed.items

    feed.next_page.should be_nil
  end

  it "stores the item count for the feed" do
    pending("Cheating on counts for a while")
    events = populate_timeline
    feed = subject.new("user_1_home")
    feed.items

    feed.count.should == events.length
  end

  it "fetches multiple objects per type" do
    protocol.record("user_1", {"name" => "akk"})
    protocol.record("user_2", {"name" => "bf"})

    event = simple_event
    event.objects["test"] = ["user_1", "user_2"]

    protocol.publish(event)
    feed = subject.create(event.timelines.first)
    feed.items.first.objects["test"].length.should == 2
  end

  it "fetches two levels of subevents" do
    pending("Cheating on sub-subevents for now")
    grouping = simple_event
    grouping.key = "grouping_1"
    grouping['data'] = {"grouping" => "flight"}
    grouping.timelines = ["subsubevent_test"]

    event = simple_event
    event.parent = grouping.key
    event.timelines = [grouping.key]

    subevent = simple_event
    subevent.key = "comment_1"
    subevent.parent = event.key
    subevent['data']['type'] = "comment"
    subevent['data']['message'] = "Great!"
    subevent.timelines = [event.key]

    protocol.publish(grouping)
    protocol.publish(event)
    protocol.publish(subevent)

    feed = subject.new("subsubevent_test", 20, nil, true)
    feed.items.first.
      subevents.first.
      subevents.first.key.should == subevent.key
  end

end

