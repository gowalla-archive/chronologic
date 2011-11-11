require 'spec_helper'

describe Chronologic::Service::Schema::Cassandra do 

  let(:protocol) { Chronologic::Service::Protocol }

  subject do
    Chronologic::Service::Schema::Cassandra
  end

  it_behaves_like "a CL schema"

  it "counts items in a timeline" do
    pending("Cheating on counts for a while")
    10.times { |i| subject.create_timeline_event("_global", i.to_s, "junk") }
    subject.timeline_count("_global").should == 10
  end

end

