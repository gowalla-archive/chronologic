require "httparty"

class Chronologic::Client

  include HTTParty

  def initialize(host)
    self.class.default_options[:base_uri] = host
  end

  def record(object_key, data)
    resp = self.class.post("/record", {"object_key" => object_key, "data" => data})
    raise Chronologic::Exception.new("Error creating new record") unless resp.code == 201
    true
  end

  def unrecord(object_key)
    resp = self.class.delete("/record/#{object_key}")
    raise Chronologic::Exception.new("Error removing record") unless resp.code == 204
    true
  end

end
