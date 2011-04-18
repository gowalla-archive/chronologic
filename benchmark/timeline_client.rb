# $ ruby -rubygems -Ilib benchmark/publish.rb

require "benchmark"
require "chronologic"

iterations = Integer(ARGV.last)

timelines = [1, 2, 3, 4, 5, 6, 3104, 1699].map { |id| ["user_#{id}", "user_#{id}_home"] }.flatten

# cl = Chronologic::Client.new("http://localhost:9292")
cl = Chronologic::Client.new('https://api.gowalla.com/services/chronologic')

if __FILE__ == $PROGRAM_NAME
  result = Benchmark.measure do
    iterations.times do
      feed = timelines.shuffle.first
      cl.timeline(feed, :subevents => true)
    end
  end

  puts "%.5fs/timeline" % [result.total/iterations]
  puts "#{result.real}s total"
end
