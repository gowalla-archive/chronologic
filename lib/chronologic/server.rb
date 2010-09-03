begin
  require 'sinatra/base'
  require 'yajl'
  require 'erb'
rescue LoadError
  require 'rubygems'
  require 'sinatra/base'
  require 'yajl'
  require 'erb'
end
require 'chronologic'

module Chronologic
  class Server < Sinatra::Base
    def initialize(options)
      super
      @connection = Connection.new(options)
    end
    
    get '/' do
      erb :index
    end
    
    delete '/' do
      @connection.clear!
      status 204
    end

    put '/objects/:object_key' do |object_key|
      @connection.object(object_key, request.POST)
      status 204
    end

    delete '/objects/:object_key' do |object_key|
      @connection.remove_object(object_key)
      status 204
    end

    put '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      @connection.subscribe(subscriber, subscription)
      status 204
    end
    
    delete '/subscriptions/:subscriber/:subscription' do |subscriber, subscription|
      @connection.unsubscribe(subscriber, subscription)
      status 204
    end

    put '/events/:event_key' do |event_key|
      @connection.event(request.POST.merge(:key => event_key))
      status 204
    end

    delete '/events/:event_key' do |event_key|
      @connection.remove_event(event_key)
      status 204
    end

    get %r{/timelines(/([\w]*))} do |nothing, timeline_key|
      opts = {}
      opts[:count] = request.GET['count'].to_i if request.GET['count']
      opts[:start] = request.GET['start'] if request.GET['start']
      timeline = @connection.timeline(timeline_key=='' ? nil : timeline_key, opts)
      timeline[:events].each do |e|
        e[:created_at] = e[:created_at].utc.iso8601
      end
      content_type :json
      Yajl::Encoder.encode(timeline)
    end
    
    template :index do
      <<-eos
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <title>Chronologic</title>
          </head>
          <body>
        	  <h1>Chronologic</h1>
        	  <h2 id="timeline_key"></h2>
        	  <ul id="timeline">
        	  </ul>
            <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js" type="text/javascript"></script>
            <script tyle="text/javascript">
              var Chronologic = {
                prettyString: function(obj, indent) {
                  var result = "";
                  if (indent == null) indent = "";
                  for (var property in obj) {
                    var value = obj[property];
                    if (typeof value == 'string') {
                      value = "'" + value + "'";
                    } else if (typeof value == 'object') {
                      if (value instanceof Array) {
                        value = "[ " + value + " ]";
                      } else {
                        var od = this.prettyString(value, indent + "  ");
                        value = "\\n" + indent + "{\\n" + od + "\\n" + indent + "}";
                      }
                    }
                    result += indent + "'" + property + "' : " + value + ",\\n";
                  }
                  return result.replace(/,\\n$/, "");
                },
                
                getTimeline: function(key) {
                  $.getJSON('/timelines/' + key, function(data) {
                    $('#timeline_key').text(key);
                    $('#timeline').text('');
                    $.each(data.events, function(i, event) {
                      $("<li/>").html('<pre>' + Chronologic.prettyString(event, '') + '</pre>').appendTo("#timeline");
                    });
                  });
                },
              }
              Chronologic.getTimeline('user_1');
            </script>
          </body>
        </html>
      eos
    end
  end
end
