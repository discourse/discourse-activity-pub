# frozen_string_literal: true

RSpec.configure { |config| config.include DiscourseActivityPub::JsonLd }

def toggle_activity_pub(model, disable: false, username: nil, publication_type: nil)
  model.reload

  if !model.activity_pub_actor
    attrs = { ap_type: DiscourseActivityPub::AP::Actor::Group.type, local: true, enabled: true }
    model.build_activity_pub_actor(attrs)
  end

  username = username || model.is_a?(Category) ? model.slug : model.name

  model.activity_pub_actor.username = username
  model.activity_pub_actor.publication_type = publication_type if publication_type
  model.activity_pub_actor.enabled = !disable
  model.activity_pub_actor.save!

  model.reload
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
  path =
    if key == "not_enabled"
      "discourse_activity_pub"
    else
      "discourse_activity_pub.request.error"
    end
  message = I18n.t("#{path}.#{key}", opts)
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

def expect_not_enabled(response)
  expect(response.status).to eq(403)
  expect(response.parsed_body).to eq({ "errors" => [I18n.t("discourse_activity_pub.not_enabled")] })
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
    keypair: (keypair.presence || actor.keypair),
    headers: (headers.presence || default_headers),
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
    keypair: (keypair.presence || actor.keypair),
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
    id: "https://remote.com/u/#{preferredUsername}/#{SecureRandom.hex(8)}",
    name: name,
    preferredUsername: preferredUsername,
    type: type,
    inbox: "https://remote.com/u/#{preferredUsername}/inbox",
    outbox: "https://remote.com/u/#{preferredUsername}/outbox",
  }
  _json[:publicKey] = {
    id: "#{_json[:id]}#main-key",
    owner: _json[:id],
    publicKeyPem: public_key,
  } if public_key
  _json.with_indifferent_access
end

def build_object_json(
  id: nil,
  type: "Note",
  name: nil,
  content: "My cool note #{SecureRandom.hex(8)}",
  in_reply_to: nil,
  published: nil,
  url: nil,
  to: nil,
  cc: nil,
  audience: nil,
  attributed_to: nil,
  context: nil,
  attachments: []
)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: id || "https://remote.com/object/#{type.downcase}/#{SecureRandom.hex(8)}",
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
  _json[:context] = context if context
  _json[:attachment] = attachments if attachments.present?
  _json.with_indifferent_access
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
    id: id || "https://remote.com/activity/#{type.downcase}/#{SecureRandom.hex(8)}",
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

def build_collection_json(
  type: "Collection",
  items: [],
  to: nil,
  cc: nil,
  audience: nil,
  name: nil,
  first_page: nil,
  last_page: nil
)
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: "https://remote.com/collection/#{SecureRandom.hex(8)}",
    type: type,
  }
  _json[:items] = items if type == "Collection"
  _json[:orderedItems] = items if type == "OrderedCollection"
  _json[:totalItems] = items.size
  _json[:to] = to if to
  _json[:cc] = cc if cc
  _json[:audience] = audience if audience
  _json[:name] = name if name
  _json[:first] = "#{_json[:id]}?page=#{first_page}" if first_page
  _json[:last] = "#{_json[:id]}?page=#{last_page}" if last_page
  _json.with_indifferent_access
end

def build_collection_page_json(
  type: "CollectionPage",
  summary: nil,
  items: [],
  part_of: nil,
  page: nil,
  next_page: nil,
  prev_page: nil
)
  return {} if items.blank? || part_of.blank?
  _json = {
    "@context": "https://www.w3.org/ns/activitystreams",
    id: "#{part_of}?page=#{page}",
    type: type,
  }
  _json[:items] = items if type == "CollectionPage"
  _json[:orderedItems] = items if type == "OrderedCollectionPage"
  _json[:summary] = summary if summary
  _json[:next] = "#{part_of}?page=#{next_page}" if next_page
  _json[:prev] = "#{part_of}?page=#{prev_page}" if prev_page
  _json.with_indifferent_access
end

def build_process_warning(key, object_id = "(object_id)")
  action = I18n.t("discourse_activity_pub.process.warning.failed_to_process", object_id: object_id)
  message = I18n.t("discourse_activity_pub.process.warning.#{key}")
  prefix_log("#{action}: #{message}")
end

def prefix_log(message)
  "[Discourse Activity Pub] #{message}"
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
      (!actor || args[:actor].id == actor.id) && (!object || args[:object].id == object.id) &&
        (!object_type || args[:object].ap_type == object_type) &&
        (!recipient_ids || args[:recipient_ids].sort == recipient_ids.sort) &&
        (!delay || args[:delay] == delay)
    end
    .once
end

def expect_no_delivery
  DiscourseActivityPub::DeliveryHandler.expects(:perform).never
end

def stub_object_request(object, body: nil, status: 200)
  object_id = object.respond_to?(:ap_id) ? object.ap_id : object[:id]
  object_json = object.respond_to?(:ap) ? object.ap.json : object
  stub_request(:get, object_id).to_return(
    body: body || object_json.to_json,
    headers: {
      "Content-Type" => "application/json",
    },
    status: status,
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

def setup_logging
  @fake_logger = FakeLogger.new
  SiteSetting.activity_pub_verbose_logging = true
  Rails.logger.broadcast_to(@fake_logger)
end

def teardown_logging
  Rails.logger.stop_broadcasting_to(@fake_logger)
  SiteSetting.activity_pub_verbose_logging = false
end

def parsed_body
  JSON.parse(response.body)
end

def read_integration_json(case_name, file_name)
  JSON.parse(
    File.open(
      File.join(
        File.expand_path(__dir__),
        "fixtures",
        "integration",
        case_name,
        "#{file_name}.json",
      ),
    ).read,
  ).with_indifferent_access
end
