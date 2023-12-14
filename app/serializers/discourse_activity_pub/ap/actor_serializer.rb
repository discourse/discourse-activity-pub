# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :inbox,
             :outbox,
             :sharedInbox,
             :followers,
             :preferredUsername,
             :publicKey,
             :url,
             :icon

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

  def include_url?
    object.stored.local?
  end

  def icon
    {
      type: "Image",
      mediaType: object.icon_media_type,
      url: object.icon_url
    }.as_json
  end

  def include_icon?
    object.stored.local?
  end

  def include_name?
    object.stored.local? && object.name.present?
  end

  def sharedInbox
    object.shared_inbox
  end

  def include_sharedInbox?
    object.shared_inbox.present?
  end
end