require 'functional_helper'

describe "Privacy controls in Chronologic" do

  include Rack::Test::Methods

  # Rewrite this from a chronologic client
  it "checks whether a user can see events for another user" do
    pending("Come back to this when you're good and sure about it")
    post '/subscription', {
      'timeline_key' => 'user_ak_feed', 
      'subscriber_key' => 'user_bo', 
      'timeline_backlink' => 'user_ak'
    }

    get '/subscription/is_connected', {
      'subscriber_key' => 'user_bo',
      'timeline_backlink' => 'user_ak'
    }
    last_response.status.must_equal 200
    obj = JSON.load(last_response.body)
    obj['user_bo'].must_equal true
  end

  it "removes private events from a timeline if the users are not connected"

  it "includes private events in a timeline if the users are connected"

  def app
    logger = Logger.new(STDOUT)
    logger.level = Logger::WARN
    Chronologic::Service.logger = logger
    Chronologic::Service.new
  end

end
