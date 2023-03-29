# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :preferredUsername

  def preferredUsername
    object.preferred_username
  end
end