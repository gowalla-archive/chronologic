require "chronologic"

Chronologic.connection = Cassandra.new("Chronologic")
run Chronologic::Service.new

