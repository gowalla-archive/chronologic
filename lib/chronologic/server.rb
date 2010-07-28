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
    set :connection, Connection.new
    
    get '/' do
      erb :index
    end
    
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

    get %r{/timelines(/([\w]*))} do |nothing, key|
      timeline = options.connection.timeline(key=='' ? nil : key)
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
        	  <h2 id="timeline_key">x</h2>
        	  <ul id="timeline">y
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
                      $("<li/>").text(Chronologic.prettyString(event, '')).appendTo("#timeline");
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
