require "chronologic"

keyspace = ENV.fetch('KEYSPACE', "ChronologicTest")
puts "Using #{keyspace}"
Chronologic.connection = Cassandra.new(keyspace)

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

Chronologic::Service::App.logger = logger
Chronologic::Service::Schema.logger = logger
run Chronologic::Service::App.new

