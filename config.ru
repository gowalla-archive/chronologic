require "chronologic"

Chronologic.connection = Cassandra.new("Chronologic")

Chronologic::Service.logger = Logger.new(STDOUT)
run Chronologic::Service.new

