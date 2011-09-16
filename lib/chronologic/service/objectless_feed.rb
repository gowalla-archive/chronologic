require 'chronologic/service/feed_boilerplate'

class Chronologic::Service::ObjectlessFeed
  include Chronologic::Service::FeedBoilerplate

  def items
    return @items if @items

    set_next_page
    set_count

    events = schema.fetch_timelines(timeline_key, per_page, start)
    subevents = schema.fetch_timelines(events.map { |e| e.key }, per_page, start)

    @items = schema.reify_timeline([events, subevents].flatten)
  end

end

