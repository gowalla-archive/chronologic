require 'sinatra/base'
require 'chronologic'

module Chronologic
  class Server < Sinatra::Base
    configure do
      CONN = Connection.new
    end

    get '/' do
      "hello world"
    end
    
    post '/clear' do
      CONN.clear!
      status 204
    end

    put '/objects/:key' do |key|
      CONN.object(key, params)
      status 204
    end
    
    delete '/objects/:key' do |key|
      CONN.remove_object(key)
      status 204
    end

    put '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      CONN.subscribe(subscriber, subscription)
      status 204
    end
    
    delete '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      CONN.unsubscribe(subscriber, subscription)
      status 204
    end

    post '/events' do
      CONN.event(
        :info => params[:info] || {},               # { :type => 'checkin', :id => '1', :message => 'Hello' }
        :key => params[:key],                       # 'checkin_1'
        :timelines => params[:timelines] || [],     # [ :user_1, :spot_1 ]
        :subscribers => params[:subscribers] || [], # [ :user_1 ]
        :objects => params[:objects] || {} ,        # { :spot => :spot_1, :user => :user_1 }
        :events => params[:events] || []            # [ :checkin_1 ] (for photos, comments, etc)
      )
      status 204
    end

    delete '/events/:key' do |key|
      CONN.remove_event(key)
      status 204
    end

    get '/timelines/:key' do |key|
      events = CONN.timeline(key)
      content_type :json
      { :events => events }.to_json
    end
  end
end
