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
    status 201
  end

  get "/record/:object_key" do
    # FIXME: stomping on Demeter here
    json connection.schema.object_for(params["object_key"])
  end

  delete "/record/:object_key" do
    connection.unrecord(params["object_key"])
    status 204
  end

  helpers do
    
    def json(object)
      JSON.dump(object)
    end

  end

end
