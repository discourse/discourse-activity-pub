# frozen_string_literal: true
module DiscourseActivityPubGuardianExtension
  def can_recover_topic?(topic)
    return false if topic&.activity_pub_enabled
    super(post)
  end

  def can_recover_post?(post)
    return false if post&.activity_pub_enabled
    super(post)
  end
end