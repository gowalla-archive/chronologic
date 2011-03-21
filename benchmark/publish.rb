# $ ruby -rubygems -Ilib benchmark/publish.rb

require "perftools"
require "benchmark"
require "chronologic"

def create_friendship(timeline, subscriber)
  Chronologic::Protocol.subscribe(timeline, subscriber)
end

def create_event(key, timeline)
  ev = Chronologic::Event.new
  ev.key = key
  ev.timestamp = Time.now
  ev.data = {"test" => true}
  ev.objects = {}
  ev.timelines = [timeline]

  Chronologic::Protocol.publish(ev)
end

def dump_results(data)
  flat = File.expand_path(File.dirname(__FILE__) + "publish_flat.txt")
  graph = File.expand_path(File.dirname(__FILE__) + "publish_graph.html")

  RubyProf::FlatPrinter.new(data).print(File.open(flat, "w"), 1)
  RubyProf::GraphHtmlPrinter.new(data).print(File.open(graph, "w"))
end

friends = 50
events = 1000
timeline = "cl_timeline"
Chronologic.connection = Cassandra.new("Chronologic")

if __FILE__ == $PROGRAM_NAME
  result = Benchmark.measure do
    friends.times { |i| create_friendship("cl_subscriber_#{i}", timeline) }
  end
  puts "%.5fms/subscribe" % [friends/result.total]

  result = Benchmark.measure do
    PerfTools::CpuProfiler.start("tmp/publish_profile") do
      events.times { |i| create_event("cl_event_#{i}", timeline) }
    end
  end
  puts "%.5fms/publish" % [events/result.total]
end
