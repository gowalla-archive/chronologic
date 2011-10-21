class Chronologic::Client::Event
  include Chronologic::Event::Behavior
  include Chronologic::Event::State

  def initialize
    @published = false
  end

  def to_transport
    {
      "key" => key,
      "data" => json_encode(data),
      "objects" => json_encode(objects),
      "timelines" => json_encode(timelines)
    }
  end

  def published?
    @published
  end

  def published!
    @published = true
  end
end
