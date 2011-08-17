require 'functional_helper'

describe "The Chronologic API" do

  let(:connection) { Chronologic::Client::Connection.instance = Chronologic::Client::Connection.new('http://localhost:9292') }

  context "GET /event/[event_key]" do

    it "returns an event"

    it "returns 404 if the event isn't present" do
      expect { connection.fetch('/event/thingy_123') }.to raise_exception(Chronologic::NotFound)
    end

  end

end
