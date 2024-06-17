# frozen_string_literal: true
module DiscourseActivityPubUserExtension
  def skip_email_validation
    self.activity_pub_actor&.remote? || super
  end
end
