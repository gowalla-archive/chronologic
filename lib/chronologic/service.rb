require "sinatra/base"

# TODO: caching headers?
class Chronologic::Service < Sinatra::Base
  attr_accessor :connection

  def initialize(connection, *params)
    super(*params)
    self.connection = connection
  end

  post "/record" do
    connection.record(params["key"], params["data"])
    status(204)
  end

end
