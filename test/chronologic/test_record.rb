require "helper"

class User
  include Chronologic::Record
end

describe Chronologic::Record do
  
  before do
    Chronologic::Client.instance = 
      Chronologic::Client.new('http://localhost:3000')
    @user = User.new
  end

  it "adds helper methods" do
    @user.methods.must_include "record"
    @user.methods.must_include "unrecord"
  end

  it "records an entity" do
    stub_request(:post, "http://localhost:3000/object").
      to_return(:status => 201)

    @user.record("user_1", {"username" => "akk"})
    assert_requested :post, "http://localhost:3000/object", :body => /user_1/
  end

  it "unrecords an entity" do
    stub_request(:delete, "http://localhost:3000/object/user_1").
      to_return(:status => 204)

    @user.unrecord("user_1")
    assert_requested :delete, "http://localhost:3000/object/user_1"
  end

end
