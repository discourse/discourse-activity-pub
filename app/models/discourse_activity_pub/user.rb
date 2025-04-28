module DiscourseActivityPub::User
  def self.prepended(user_class)
    user_class.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model
    user_class.has_many :activity_pub_authorizations,
                        -> { active },
                        class_name: "DiscourseActivityPubAuthorization"
    user_class.skip_callback :create, :after, :create_email_token, if: -> { self.skip_email_validation }
    user_class.before_validation :activity_pub_skip_email_validation
  end

  def activity_pub_enabled
    DiscourseActivityPub.enabled
  end

  def activity_pub_ready?
    true
  end

  def activity_pub_allowed?
    true
  end

  def activity_pub_url
    full_url
  end

  def activity_pub_icon_url
    avatar_template_url.gsub("{size}", "96")
  end

  def activity_pub_shared_inbox
    DiscourseActivityPub.users_shared_inbox
  end

  def activity_pub_username
    username
  end

  def activity_pub_name
    name
  end

  def activity_pub_skip_email_validation
    if self.instance_variable_get(:@skip_email_validation).nil? && self.activity_pub_actor&.remote?
      self.instance_variable_set(:@skip_email_validation, true)
    end
  end
end