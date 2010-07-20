require 'chronologic/connection'
require 'chronologic/version'
require 'chronologic/errors'

module Chronologic
  #extend self
  #
  def cassandra=(cassandra)
    @cassandra = cassandra
  end
  
  def cassandra
    return @cassandra if @cassandra
    self.cassandra = Cassandra.new('Chronologic')
    self.cassandra
  end
end