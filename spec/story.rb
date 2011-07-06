class Story
  class User
    attr_accessor :username, :age

    def to_cl_key
      'user_1'
    end

    def from_cl(attrs)
      self.username = attrs['username']
      self.age = attrs['age']
      self
    end

    def <=>(other)
      self.age <=> other.age
    end
  end

  class Activity
    def from_cl(attrs)
      case attrs['type']
      when 'photo'
        Photo.new.from_cl(attrs)
      when 'comment'
        Comment.new.from_cl(attrs)
      end
    end
  end

  class Photo < Activity
    attr_accessor :message, :url, :timestamp

    def to_cl_key
      'photo_1'
    end

    def from_cl(attrs)
      self.message = attrs['message']
      self.url = attrs['url']
      self.timestamp = attrs['timestamp']
      self
    end

    def <=>(other)
      self.timestamp <=> other.timestamp
    end
  end

  include Chronologic::Client::Event

  attribute :title

  objects :users, User
  events :activities, Activity
end
