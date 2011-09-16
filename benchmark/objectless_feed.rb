require 'chronologic'
require 'benchmark'

n_events = 100
# n_objects = rand(10)
n_objects = 20
n_feeds = 1000

Chronologic.connection = Cassandra.new('Chronologic')
protocol = Chronologic::Service::Protocol

timestamp = Time.now.tv_sec
timeline = ['objectless', timestamp].join('-')
puts "Benchmarking for #{timeline}"
puts Benchmark.measure {
  n_events.times do |i|
    objects = n_objects.times.map do |n|
      key = ['object', timestamp, n].join('-')
      data = {'value' => 'b' * 512}
      protocol.record(key, data)
      key
    end

    event = Chronologic::Event.new(
      :key => ['objectless', timestamp, i].join('-'),
      :data => {'foo' => 'a' * 768},
      :objects => {'things' => objects},
      :timelines => [timeline]
    )
    protocol.publish(event)
  end
}

Benchmark.bmbm(20) do |x|

  x.report("feed") do
    n_feeds.times { protocol.feed(timeline, :per_page => 20).items }
  end

  x.report("objectless") do
    n_feeds.times { protocol.feed(timeline, :per_page => 20, :strategy => "objectless").items }
  end

end

