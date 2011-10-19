require 'spec_helper'

describe Chronologic::Client::Event do
  it_behaves_like "a CL event"

  let(:event) { simple_event(:new_client) }

  it "serializes for HTTP transport" do
    event.to_transport.should_not have_key("timestamp")
    event.to_transport["data"].should == MultiJson.encode(event.data)
    event.to_transport["objects"].should == MultiJson.encode(event.objects)
    event.to_transport["timelines"].should == MultiJson.encode(event.timelines)
    event.to_transport["key"].should == event.key
  end

  it "is unpublished by default" do
    event.published?.should == false
  end

  it "toggles published state" do
    event.published!
    event.published?.should == true
  end

end
