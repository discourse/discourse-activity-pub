# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :preferredUsername,
             :publicKey

  def preferredUsername
    object.preferred_username
  end

  def publicKey
    object.public_key
  end

  def include_publicKey?
    object.public_key.present?
  end
end