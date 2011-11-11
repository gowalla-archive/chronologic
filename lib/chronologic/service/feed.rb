require 'chronologic/service/feed_boilerplate'

class Chronologic::Service::Feed
  include Chronologic::Service::FeedBoilerplate

  def items
    return @items if @items

    set_next_page
    set_count

    events = fetch_timelines(timeline_key, per_page, start)
    subevents = fetch_timelines(events.map { |e| e.key }, per_page, start)

    all_events = fetch_objects([events, subevents].flatten)
    @items = reify_timeline(all_events)
  end

end

