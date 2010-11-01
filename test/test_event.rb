require "helper"

describe Chronologic::Event do

  before do
    @event = Chronologic::Event.new
  end

  it "detects nested data" do
    @event.data = {"foo" => [1, 2]}
    @event.data_is_nested?.must_equal true

    @event.data = {"foo" => {"bar" => 1}}
    @event.data_is_nested?.must_equal true
  end

end
