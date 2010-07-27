begin
  require 'sinatra/base'
rescue LoadError
  require 'rubygems'
  require 'sinatra/base'
end
require 'chronologic'

module Chronologic
  class Server < Sinatra::Base
    set :connection, Connection.new
    
    delete '/' do
      options.connection.clear!
      status 204
    end

    put '/objects/:key' do |key|
      options.connection.object(key, params)
      status 204
    end

    get '/objects/:key' do |key|
      object = options.connection.get_object(key)
      content_type :json
      { :object => object }.to_json
    end
    
    delete '/objects/:key' do |key|
      options.connection.remove_object(key)
      status 204
    end

    put '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      options.connection.subscribe(subscriber, subscription)
      status 204
    end
    
    delete '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      options.connection.unsubscribe(subscriber, subscription)
      status 204
    end

    put '/events/:key' do |key|
      opts = JSON.parse(request.body.read)
      options.connection.event(key,
        :data        => opts['data'],
        :timelines   => opts['timelines'],
        :subscribers => opts['subscribers'],
        :objects     => opts['objects'],
        :events      => opts['events']
      )
      status 204
    end

    delete '/events/:key' do |key|
      options.connection.remove_event(key)
      status 204
    end

    get '/timelines/:key' do |key|
      events = options.connection.timeline(key)
      content_type :json
      { :events => events }.to_json
    end
  end
end
