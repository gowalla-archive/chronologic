require 'chronologic'
require 'rails'

module Chronologic
  class Railtie < Rails::Railtie
    railtie_name :chronologic

    #config.middlewares.use MyRailtie::Middleware

    #initializer "chronologic.configure_rails_initialization" do
    #  #some initialization behavior
    #end
    #rake_tasks do
    #  load "path/to/my_railtie.tasks"
    #end
    #generators do
    #  require "path/to/my_railtie_generator"
    #end
    #ActiveSupport::Notifications.instrument "my_railtie.something_expensive" do
    #  # something expensive
    #end
    #
    #class MyRailtie::Subscriber < Rails::Subscriber
    #  def something_expensive(event)
    #    info("Something expensive took %.1fms" % event.duration)
    #  end
    #end
    #
    #class MyRailtie < Railtie
    #  subscriber MyRailtie::Subscriber.new
    #end    
  end
end
 