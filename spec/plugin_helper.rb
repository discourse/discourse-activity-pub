# frozen_string_literal: true

RSpec.configure do |config|
  config.include DiscourseActivityPub::JsonLd
end

def enable_activity_pub(category, with_actor: false)
  category.custom_fields['activity_pub_enabled'] = true
  category.custom_fields['activity_pub_username'] = category.slug

  if with_actor
    category.save!
    category.reload
  else
    category.save_custom_fields(true)
  end
end