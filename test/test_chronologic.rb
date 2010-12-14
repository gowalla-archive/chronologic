require "helper"

describe Chronologic do

  it "holds a Cassandra connection" do
    fake_connection = Object.new
    Chronologic.connection = fake_connection
    Chronologic.connection.must_equal fake_connection
  end

  it "has a schema helper" do
    Chronologic.schema.must_equal Chronologic::Schema
  end

end
