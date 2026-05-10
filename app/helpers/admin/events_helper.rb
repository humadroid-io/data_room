module Admin::EventsHelper
  def event_kind_badge(event)
    tag.span(event.kind.titleize,
             class: "badge badge-soft badge-sm",
             style: "background-color: #{event.color}1A; color: #{event.color}; border-color: #{event.color}33;")
  end
end
