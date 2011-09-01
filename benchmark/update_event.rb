require "perftools"
require "benchmark"
require "logger"
require "chronologic"

Chronologic.connection = Cassandra.new("Chronologic")

# logger = Logger.new(STDOUT)
# logger.level = Logger::DEBUG
# Chronologic::Service::Schema.logger = logger

protocol = Chronologic::Service::Protocol

subscriber_count = Integer(ARGV.first)
event_count = Integer(ARGV.last)

start = Time.now.tv_sec

result = Benchmark.measure do
  first_timeline = "update_events_bench_0"
  other_timeline = "update_events_bench_1"
  events = []

  subscriber_count.times do |n|
    protocol.subscribe("ue_sink_#{n}", first_timeline)
    protocol.subscribe("ue_sink_#{n}", other_timeline)
  end

  event_create = Benchmark.measure do
    events = event_count.times.map do |n|
      event = Chronologic::Event.new(
        "key" => "ue_event_#{start}_#{n}",
        "data" => {"blah" => "This is #{n}"},
        "objects" => {},
        "timelines" => [first_timeline]
      )
      protocol.publish(event)
      event
    end
  end

  puts "%.5fs/publish" % [event_create.total/event_count]
  puts "#{event_create.total}s total"

  # Create n events
  event_update = Benchmark.measure do
    PerfTools::CpuProfiler.start("tmp/update_events_after_#{subscriber_count}_#{event_count}") do
      events.each do |event|
        event.timelines = [first_timeline, other_timeline]
        protocol.update_event(event, true)
      end
    end
  end
  puts "%.5fs/update_event" % [event_update.total/event_count]
  puts "#{event_update.total}s total"

end

puts "#{result.total}s total"
