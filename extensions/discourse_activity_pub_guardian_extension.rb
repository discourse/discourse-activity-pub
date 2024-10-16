# frozen_string_literal: true

# TODO (future): PR discourse/discourse to add plugin api for guardian changes.
# TODO (future): PR discourse/discourse to add a proper guardian condition for changing post owners.

module DiscourseActivityPubGuardianExtension
  def can_edit_post?(post)
    return false if post.activity_pub_remote?
    super
  end

  def can_change_post_owner?
    return false if activity_pub_change_owner_restricted?
    super
  end

  def activity_pub_change_owner_restricted?
    return false unless DiscourseActivityPub.enabled && request&.params&.[]("topic_id")
    topic = Topic.find_by(id: request.params["topic_id"].to_i)
    topic && (topic.activity_pub_remote? || topic.activity_pub_published?)
  end

  def can_admin?(actor)
    case actor.model_type
    when "Category"
      can_edit?(actor.model)
    when "Tag"
      can_admin_tags?
    end
  end
end
