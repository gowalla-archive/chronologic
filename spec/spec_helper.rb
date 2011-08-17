require 'chronologic'
require 'webmock/rspec'
require 'cassandra/mock'
require 'helpers'

RSpec.configure do |config|
  config.include(ChronologicHelpers)
  config.include(WebMock::API)

  config.before do
    if ENV['CASSANDRA']
      Chronologic::Service::Schema.write_opts = {
        :consistency => Cassandra::Consistency::ONE
      }
      Chronologic.connection = Cassandra.new(
        'ChronologicTest',
        ['127.0.0.1:9160'],
        :connection_timeout => 3,
        :retries => 2,
        :timeout => 3
      )
      clean_up_keyspace!(Chronologic.connection)
    else
      schema = {
        'Chronologic' => {
          'Object' => {},
          'Subscription' => {},
          'Event' => {},
          'Timeline' => {}
        }
      }
      Chronologic.connection = Cassandra::Mock.new('Chronologic', schema)
    end
  end

  config.before do
    WebMock.disable_net_connect!
    WebMock.reset!
  end

end

