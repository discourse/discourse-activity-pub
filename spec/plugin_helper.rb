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

def build_headers(object, verb, custom = {})
  content_key = verb == :get ? "Accept" : "Content-Type"
  headers = { "#{content_key}" => custom[:content_header] || DiscourseActivityPub::JsonLd.content_type_header }
  headers["Date"] = custom[:date_header] || Date.now

end

def get_object(object, url: nil, headers: {})
  get (url || object.ap_id), headers: {
    "Accept" => DiscourseActivityPub::JsonLd.content_type_header
  }.merge(headers)
end

def post_to_inbox(object, url: nil, body: {}, headers: {})
  post (url || object.inbox), headers: {
    "RAW_POST_DATA" => body.to_json,
    "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header
  }.merge(headers)
end

def get_from_outbox(object, url: nil, headers: {})
  get (url || object.outbox), headers: {
    "Accept" => DiscourseActivityPub::JsonLd.content_type_header
  }.merge(headers)
end

def activity_request_error(key)
  { "errors" => [I18n.t("discourse_activity_pub.request.error.#{key}")] }
end

def build_actor_json(public_key = nil)
  _json = {
    '@context': 'https://www.w3.org/ns/activitystreams',
    id: "https://external.com/u/angus",
    type: "Person",
    inbox: "https://external.com/u/angus/inbox",
    outbox: "https://external.com/u/angus/outbox"
  }
  _json[:publicKey] = {
    id: "#{_json[:id]}#main-key",
    owner: _json[:id],
    publicKeyPem: public_key
  } if public_key
  _json
end

def build_follow_json(actor = nil)
  {
    '@context': 'https://www.w3.org/ns/activitystreams',
    id: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
    type: 'Follow',
    actor: build_actor_json,
    object: actor ? actor.ap_id : DiscourseActivityPub::JsonLd.json_ld_id('Actor', SecureRandom.hex(16))
  }.with_indifferent_access
end

def build_process_warning(key, object_id)
  action = I18n.t("discourse_activity_pub.process.warning.failed_to_process", object_id: object_id)
  message = I18n.t("discourse_activity_pub.process.warning.#{key}")
  "[Discourse Activity Pub] #{action}: #{message}"
end