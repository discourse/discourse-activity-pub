# frozen_string_literal: true

class DiscourseActivityPub::AP::OutboxesController < DiscourseActivityPub::AP::ActorsController
  def index
    render_ordered_collection(@actor, "outbox")
  end
end
