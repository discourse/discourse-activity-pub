# frozen_string_literal: true

class DiscourseActivityPub::AP::FollowersController < DiscourseActivityPub::AP::ActorsController
  requires_plugin DiscourseActivityPub::PLUGIN_NAME

  def index
    render_ordered_collection(@actor, "followers")
  end
end
