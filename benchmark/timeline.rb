# $ ruby -rubygems -Ilib benchmark/publish.rb

require "perftools"
require "benchmark"
require "logger"
require "chronologic"

servers = [
  '10.250.203.127:9160',
  '10.210.13.171:9160',
  '10.250.227.63:9160',
  '10.250.230.111:9160'
]

Chronologic.connection = Cassandra.new(
  "Chronologic", 
  servers, 
  :retries => 3
)
# logger = Logger.new(STDOUT)
# logger.level = Logger::DEBUG
# Chronologic::Schema.logger = logger

iterations = Integer(ARGV.last)

timelines = [1, 2, 3, 4, 5, 6, 3104, 1699].map { |id| ["user_#{id}", "user_#{id}_home"] }.flatten
if __FILE__ == $PROGRAM_NAME
  result = Benchmark.measure do
    PerfTools::CpuProfiler.start("tmp/timeline_profile") do
      iterations.times do
        feed = timelines.shuffle.first
        Chronologic::Protocol.feed(feed, :fetch_subevents => true).items
      end
    end
  end

  puts "%.5fs/timeline" % [result.total/iterations]
  puts "#{result.total}s total"
end
