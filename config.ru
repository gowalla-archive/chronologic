require "chronologic"

Chronologic.connection = Cassandra.new("Chronologic")

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

Chronologic::Service.logger = logger
Chronologic::Schema.logger = logger
run Chronologic::Service.new

