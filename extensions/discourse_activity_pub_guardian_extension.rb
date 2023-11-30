# frozen_string_literal: true

# TODO (future): PR discourse/discourse to add plugin api for guardian changes.
# TODO (future): PR discourse/discourse to add a proper guardian condition for changing post owners.

module DiscourseActivityPubGuardianExtension
  def can_edit_post?(post)
    return false if post.activity_pub_remote?
    super
  end

  def can_change_post_owner?
    return false if activity_pub_enabled_topic?
    super
  end

  def activity_pub_enabled_topic?
    return false unless DiscourseActivityPub.enabled && request&.params["topic_id"]
    topic = Topic.find_by(id: request.params["topic_id"].to_i)
    topic&.activity_pub_enabled
  end
end
