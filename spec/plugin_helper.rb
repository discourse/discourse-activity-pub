# frozen_string_literal: true

RSpec.configure do |config|
  config.include DiscourseActivityPub::JsonLd
end

def toggle_activity_pub(category, with_actor: false, disable: false)
  category.custom_fields['activity_pub_enabled'] = !disable
  category.custom_fields['activity_pub_username'] = category.slug

  if with_actor
    category.save!
    category.reload
  else
    category.save_custom_fields(true)
  end
end

def get_object(object, custom_url: nil, custom_content_header: nil)
  get (custom_url || object.ap_id), headers: {
    "Accept" => custom_content_header || DiscourseActivityPub::JsonLd.content_type_header
  }
end

def post_to_inbox(object, body: {}, custom_url: nil, custom_content_header: nil)
  post (custom_url || object.inbox), headers: {
    "RAW_POST_DATA" => body.to_json,
    "Content-Type" => custom_content_header || DiscourseActivityPub::JsonLd.content_type_header
  }
end

def get_from_outbox(object, custom_url: nil, custom_content_header: nil)
  get (custom_url || object.outbox), headers: {
    "Accept" => custom_content_header || DiscourseActivityPub::JsonLd.content_type_header
  }
end

def activity_request_error(key)
  { "errors" => [I18n.t("discourse_activity_pub.activity.error.#{key}")] }
end

def build_follow_json(actor = nil)
  {
    '@context': 'https://www.w3.org/ns/activitystreams',
    id: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
    type: 'Follow',
    actor: {
      id: "https://external.com/u/angus",
      type: "Person",
      inbox: "https://external.com/u/angus/inbox",
      outbox: "https://external.com/u/angus/outbox"
    },
    object: actor ? actor.ap_id : DiscourseActivityPub::JsonLd.json_ld_id('Actor', SecureRandom.hex(16))
  }.with_indifferent_access
end