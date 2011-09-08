require 'chronologic'
require 'rack/test'
require 'helpers'

module FunctionalTestHelpers

  def self.truncate_cfs
    c = Cassandra.new("ChronologicTest")
    [:Object, :Subscription, :Timeline, :Event].each do |cf|
      c.truncate!(cf)
    end
  end

  def truncate_cfs
    FunctionalTestHelpers.truncate_cfs
  end

  # AKK Could this move into an RSpec let?
  def connection
    @connection ||= Chronologic::Client::Connection.new('http://localhost:7979')
  end

end

RSpec.configure do |config|
  config.include ChronologicHelpers
  config.include(FunctionalTestHelpers)

  config.before { FunctionalTestHelpers.truncate_cfs }
end
