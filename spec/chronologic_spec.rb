require 'spec_helper'

describe Chronologic do

  it "holds a Cassandra connection" do
    fake_connection = Object.new
    Chronologic.connection = fake_connection
    Chronologic.connection.should eq(fake_connection)
  end

  it "has a schema helper" do
    Chronologic.schema.should eq(Chronologic::Service::Schema)
  end

end
