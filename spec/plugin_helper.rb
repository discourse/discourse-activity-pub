# frozen_string_literal: true

RSpec.configure { |config| config.include DiscourseActivityPub::JsonLd }

def toggle_activity_pub(
  category,
  callbacks: false,
  disable: false,
  username: nil,
  publication_type: nil
)
  category.reload

  username = username || category.slug

  category.custom_fields["activity_pub_enabled"] = !disable
  category.custom_fields["activity_pub_username"] = username
  category.custom_fields["activity_pub_publication_type"] = publication_type if publication_type

  if callbacks
    category.save!
    if !category.activity_pub_actor
      actor_opts = { username: username }
      actor_opts[:publication_type] = publication_type if publication_type
      DiscourseActivityPub::ActorHandler.update_or_create_actor(category, actor_opts)
    end
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

def expect_request_error(response, key, status, opts = {})
  expect(response.status).to eq(status)
  message = I18n.t("discourse_activity_pub.request.error.#{key}", opts)
  log =
    I18n.t(
      "discourse_activity_pub.request.error.request_from_failed",
      method: response.request.method,
      uri: response.request.url,
      status: status,
      message: message,
    )
  expect(@fake_logger.warnings).to include("[Discourse Activity Pub] #{log}")
  expect(response.parsed_body).to eq({ "errors" => [message] })
end

def default_headers
  { "Host" => DiscourseActivityPub.host, "Date" => Time.now.utc.httpdate }
end

def build_signature(
  actor: nil,
  verb: "get",
  path: DiscourseActivityPub.host,
  key_id: nil,
  keypair: nil,
  headers: {},
  params: {}
)
  DiscourseActivityPub::Request.build_signature(
    verb: verb,
    path: path,
    key_id: key_id || signature_key_id(actor),
    keypair: keypair.present? ? keypair : actor.keypair,
    headers: headers.present? ? headers : default_headers,
    custom_params: params,
  )
end

def build_headers(
  object: nil,
  actor: nil,
  verb: nil,
  path: nil,
  key_id: nil,
  keypair: nil,
  headers: {},
  params: {}
)
  return {} unless object && actor
  _headers = default_headers.merge(headers)
  _headers["Signature"] = build_signature(
    verb: verb,
    path: path || DiscourseActivityPub::URI.parse(object.ap_id).path,
    key_id: key_id || signature_key_id(actor),
    keypair: keypair.present? ? keypair : actor.keypair,
    headers: _headers,
    params: params,
  )
  _headers
end

def build_actor_json(
  type: "Person",
  name: "Angus McLeod",
  preferredUsername: "angus",
  public_key: nil
)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: "https://external.com/u/#{preferredUsername}",
    name: name,
    preferredUsername: preferredUsername,
    type: type,
    inbox: "https://external.com/u/#{preferredUsername}/inbox",
    outbox: "https://external.com/u/#{preferredUsername}/outbox",
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
  name: nil,
  content: "My cool note",
  in_reply_to: nil,
  published: nil,
  url: nil,
  to: nil,
  cc: nil,
  audience: nil,
  attributed_to: nil
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
  _json[:to] = to if to
  _json[:cc] = cc if cc
  _json[:audience] = audience if audience
  _json[:name] = name if name
  _json[:attributedTo] = if attributed_to.respond_to?(:ap_id)
    attributed_to.ap_id
  elsif attributed_to.respond_to?(:id)
    attributed_to.id
  else
    attributed_to
  end
  _json
end

def build_activity_json(
  id: nil,
  actor: nil,
  object: nil,
  type: "Follow",
  published: nil,
  to: nil,
  cc: nil,
  audience: nil
)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: id || "https://external.com/activity/#{type.downcase}/#{SecureRandom.hex(8)}",
    type: type,
    actor:
      if actor.respond_to?(:ap)
        actor.ap.json
      elsif actor.present?
        actor
      else
        build_actor_json
      end,
    object:
      if object.respond_to?(:ap)
        object.ap.json
      elsif object.present?
        object
      else
        build_object_json
      end,
    published: published || Time.now.iso8601,
  }
  _json[:to] = to if to
  _json[:cc] = cc if cc
  _json[:audience] = audience if audience
  _json.with_indifferent_access
end

def build_collection_json(type: "Collection", items: [], to: nil, cc: nil, audience: nil)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: "https://external.com/collection/#{SecureRandom.hex(8)}",
    type: type,
    items: items,
  }
  _json[:to] = to if to
  _json[:cc] = cc if cc
  _json[:audience] = audience if audience
  _json.with_indifferent_access
end

def build_process_warning(key, object_id)
  action = I18n.t("discourse_activity_pub.process.warning.failed_to_process", object_id: object_id)
  message = I18n.t("discourse_activity_pub.process.warning.#{key}")
  "[Discourse Activity Pub] #{action}: #{message}"
end

def perform_process(json, delivered_to = nil)
  klass = described_class.new
  klass.json = json
  klass.delivered_to << delivered_to if delivered_to
  klass.process
end

def expect_delivery(actor: nil, object: nil, object_type: nil, delay: nil, recipient_ids: nil)
  DiscourseActivityPub::DeliveryHandler
    .expects(:perform)
    .with do |args|
      args[:actor].id == actor.id && (!actor || args[:actor].id == actor.id) &&
        (!object || args[:object].id == object.id) &&
        (!object_type || args[:object].ap_type == object_type) &&
        (!recipient_ids || args[:recipient_ids].sort == recipient_ids.sort) && args[:delay] == delay
    end
    .once
end

def expect_no_delivery
  DiscourseActivityPub::DeliveryHandler.expects(:perform).never
end

def stub_stored_request(object)
  stub_request(:get, object.ap_id).to_return(
    body: object.ap.json.to_json,
    headers: {
      "Content-Type" => "application/json",
    },
    status: 200,
  )
end

def published_json(object, args = {})
  object.before_deliver
  object.ap.json
end

def expect_no_request
  DiscourseActivityPub::Request.expects(:new).never
end

def expect_request(body: nil, body_type: nil, actor_id: nil, uri: nil, returns: nil)
  DiscourseActivityPub::Request
    .expects(:new)
    .with do |args|
      (!actor_id || args[:actor_id] == actor_id) && (!uri || [*uri].include?(args[:uri])) &&
        (!body || args[:body][:id] == body[:id]) && (!body_type || args[:body][:type] == body_type)
    end
    .returns(returns)
end

def expect_post(returns: true)
  DiscourseActivityPubActivity.any_instance.expects(:before_deliver).once

  DiscourseActivityPub::Request.any_instance.expects(:post_json_ld).returns(returns)

  if returns
    DiscourseActivityPub::DeliveryFailureTracker.any_instance.expects(:track_success).once
    DiscourseActivityPubActivity.any_instance.expects(:after_deliver).with(true).once
  else
    DiscourseActivityPub::DeliveryFailureTracker.any_instance.expects(:track_failure).once
    DiscourseActivityPubActivity.any_instance.expects(:after_deliver).with(false).once
  end
end

def setup_logging
  SiteSetting.activity_pub_verbose_logging = true
  @orig_logger = Rails.logger
  Rails.logger = @fake_logger = FakeLogger.new
end

def teardown_logging
  Rails.logger = @orig_logger
  SiteSetting.activity_pub_verbose_logging = false
end

def parsed_body
  JSON.parse(response.body)
end
