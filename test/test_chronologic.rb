require "helper"

describe Chronologic do

  it "holds a Cassandra connection" do
    Chronologic.connection = Cassandra.new("Chronologic")
    Chronologic.connection.must_be_kind_of Cassandra
  end

  it "has a schema helper" do
    Chronologic.schema.must_equal Chronologic::Schema
  end

end
