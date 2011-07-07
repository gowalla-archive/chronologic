require "chronologic"

Chronologic.connection = Cassandra.new("Chronologic")

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

Chronologic::Service::App.logger = logger
Chronologic::Service::Schema.logger = logger
run Chronologic::Service::App.new

