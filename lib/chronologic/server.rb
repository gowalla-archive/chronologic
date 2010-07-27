begin
  require 'sinatra/base'
  require 'yajl'
rescue LoadError
  require 'rubygems'
  require 'sinatra/base'
  require 'yajl'
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
      options.connection.object(key, request.POST)
      status 204
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
      options.connection.event(key, Yajl::Parser.parse(request.body))
      status 204
    end

    delete '/events/:key' do |key|
      options.connection.remove_event(key)
      status 204
    end

    get '/timelines/:key' do |key|
      events = options.connection.timeline(key)
      content_type :json
      Yajl::Encoder.encode({ :events => events })
    end
  end
end
