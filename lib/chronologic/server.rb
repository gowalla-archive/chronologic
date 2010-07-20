require 'sinatra/base'
require 'chronologic'

module Chronologic
  class Server < Sinatra::Base
    configure do
      db = Cassandra.new('Chronologic')
      #db.clear_keyspace!
      CONN = Connection.new(db)
    end

    # not_found do
    #   'Not found'
    # end
    #      
    # get '/' do
    #   "hello world"
    # end

    put '/objects/:key' do |key|
      CONN.insert_object(key, params)
      status 204
    end
    
    delete '/objects/:key' do |key|
      CONN.remove_object(key)
      status 204
    end

    put '/subscriptions/:subject/:target' do |subject, target|
      CONN.insert_subscription(subject, target)
      status 204
    end
    
    delete '/subscriptions/:subject/:target' do |subject, target|
      CONN.remove_subscription(subject, target)
      status 204
    end

    post '/events' do
      event_info = params[:event] || {}         # { :type => 'checkin', :id => '1', :message => 'Hello' }
      key = params[:key]                        # 'checkin_1'
      objects = params[:objects] || []          # [ { :name => 'spot', :key => 'spot_1' }, { :name => 'user', :key => 'user_1' } ]
      events = params[:events] || []            # [ :checkin_1 ] (for photos, comments, etc)
      timelines = params[:timelines] || []      # [ :user_1, :spot_1 ]
      subscribers = params[:subscribers] || []  # [ :user_1 ]
      CONN.insert_event(event_info, :key => key, :objects => objects, :events => events, :timelines => timelines, :subscribers => subscribers)
      status 204
    end

    delete '/events/:key' do |key|
      CONN.remove_event(key)
      status 204
    end

    get '/timelines/:key' do |key|
      events = CONN.get_timeline(key)
      content_type :json
      { :events => events }.to_json
    end
  end
end
