# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :inbox,
             :outbox,
             :followers,
             :preferredUsername,
             :publicKey

  def followers
    "#{object.id}/followers"
  end

  def include_followers?
    object.stored.local?
  end

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