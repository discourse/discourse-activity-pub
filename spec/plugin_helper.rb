# frozen_string_literal: true

RSpec.configure { |config| config.include DiscourseActivityPub::JsonLd }

def toggle_activity_pub(
  category,
  callbacks: false,
  disable: false,
  username: nil,
  publication_type: nil
)
  category.custom_fields["activity_pub_enabled"] = !disable
  category.custom_fields["activity_pub_username"] = username || category.slug
  category.custom_fields["activity_pub_publication_type"] = publication_type if publication_type

  if callbacks
    category.save!
    category.reload
  else
    category.save_custom_fields(true)
  end
end

def get_object(object, url: nil, headers: {})
  get (url || object.ap_id),
      headers: { "Accept" => DiscourseActivityPub::JsonLd.content_type_header }.merge(headers)
end

def post_to_inbox(object, url: nil, body: {}, headers: {})
  post (url || object.inbox),
       headers: {
         "RAW_POST_DATA" => body.to_json,
         "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
       }.merge(headers)
end

def get_from_outbox(object, url: nil, headers: {})
  get (url || object.outbox),
      headers: { "Accept" => DiscourseActivityPub::JsonLd.content_type_header }.merge(headers)
end

def get_followers(object, url: nil, headers: {})
  get (url || "#{object.ap_id}/followers"),
      headers: { "Accept" => DiscourseActivityPub::JsonLd.content_type_header }.merge(headers)
end

def activity_request_error(key)
  { "errors" => [I18n.t("discourse_activity_pub.request.error.#{key}")] }
end

def build_actor_json(public_key = nil)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: "https://external.com/u/angus",
    type: "Person",
    inbox: "https://external.com/u/angus/inbox",
    outbox: "https://external.com/u/angus/outbox",
  }
  _json[:publicKey] = {
    id: "#{_json[:id]}#main-key",
    owner: _json[:id],
    publicKeyPem: public_key,
  } if public_key
  _json
end

def build_object_json(
  id: nil,
  type: "Note",
  content: "My cool note",
  in_reply_to: nil,
  published: nil,
  url: nil
)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: id || "https://external.com/object/#{type.downcase}/#{SecureRandom.hex(8)}",
    type: type,
    content: content,
    inReplyTo: in_reply_to,
    published: published || Time.now.iso8601,
  }
  _json[:url] = url if url
  _json
end

def build_activity_json(id: nil, actor: nil, object: nil, type: "Follow", published: nil)
  {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: id || "https://external.com/activity/#{type.downcase}/#{SecureRandom.hex(8)}",
    type: type,
    actor: actor ? actor.ap.json : build_actor_json,
    object:
      if object&.respond_to?(:ap)
        object.ap.json
      elsif object.present?
        object
      else
        build_object_json
      end,
    published: published || Time.now.iso8601,
  }.with_indifferent_access
end

def build_process_warning(key, object_id)
  action = I18n.t("discourse_activity_pub.process.warning.failed_to_process", object_id: object_id)
  message = I18n.t("discourse_activity_pub.process.warning.#{key}")
  "[Discourse Activity Pub] #{action}: #{message}"
end

def perform_process(json)
  klass = described_class.new
  klass.json = json
  klass.process
end

def expect_delivery(actor: nil, object: nil, object_type: nil, delay: nil)
  DiscourseActivityPub::DeliveryHandler
    .expects(:perform)
    .with do |args|
      args[:actor].id == actor.id && (!actor || args[:actor].id == actor.id) &&
        (!object || args[:object].id == object.id) &&
        (!object_type || args[:object].ap_type == object_type) && args[:delay] == delay
    end
    .once
end

def expect_no_delivery
  DiscourseActivityPub::DeliveryHandler.expects(:perform).never
end
