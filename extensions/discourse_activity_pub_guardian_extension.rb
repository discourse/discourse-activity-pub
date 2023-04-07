# frozen_string_literal: true
module DiscourseActivityPubGuardianExtension
  def can_recover_post?(post)
    return false if post&.activity_pub_enabled
    super(post)
  end

  def can_edit_post?(post)
    return false if post&.activity_pub_enabled && !post.activity_pub_pre_publication?
    super(post)
  end
end