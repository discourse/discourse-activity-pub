# frozen_string_literal: true

module DiscourseActivityPub
  module JsonLd
    ACTIVITY_STREAMS_CONTEXT = "https://www.w3.org/ns/activitystreams"
    REQUIRED_CONTEXTS = [ACTIVITY_STREAMS_CONTEXT]
    REQUIRED_PROPERTIES = %w[id type]
    LD_CONTENT_TYPE = "application/ld+json"
    ACTIVITY_CONTENT_TYPE = "application/activity+json"
    CONTENT_TYPES = [LD_CONTENT_TYPE, ACTIVITY_CONTENT_TYPE]
    PUBLIC_COLLECTION_IDS = %w[https://www.w3.org/ns/activitystreams#Public as:Public Public]

    def validate_json_ld(json)
      parsed_json = parse_json_ld(json)
      unless parsed_json && required_contexts?(parsed_json) && required_properties?(parsed_json)
        return false
      end
      format_jsonld(parsed_json)
    end

    def parse_json_ld(value)
      result = JSON.parse(value)
      return false unless result.is_a?(Hash) || result.is_a?(Array)
      result
    rescue JSON::ParserError, TypeError
      false
    end

    def format_jsonld(value)
      # TODO (future): add support for expanded JSON-LD; see https://github.com/ruby-rdf/json-ld
      value.with_indifferent_access
    end

    def required_contexts?(json)
      REQUIRED_CONTEXTS & [*json["@context"]] == REQUIRED_CONTEXTS
    end

    def required_properties?(json)
      REQUIRED_PROPERTIES.all? { |p| json.key?(p) }
    end

    def domain_from_id(id)
      DiscourseActivityPub::URI.domain_from_uri(id)
    end

    def resolve_id(raw_object)
      raw_object.is_a?(String) ? raw_object : raw_object["id"]
    end

    def resolve_object(raw_object)
      raw_object.is_a?(String) ? request_object(raw_object) : raw_object
    end

    def request_object(uri)
      Request.get_json_ld(uri: uri)
    end

    def json_ld_id(ap_base_type, ap_key)
      "#{DiscourseActivityPub.base_url}/ap/#{ap_base_type.downcase}/#{ap_key}"
    end

    def signature_key_id(actor)
      "#{actor.ap_id}#main-key"
    end

    def valid_content_type?(value)
      return false unless value.present?
      type = value.split(";").first.strip

      # technically we should require a profile=ACTIVITY_STREAMS_CONTEXT here too
      # see https://www.w3.org/TR/activitypub/#delivery
      CONTENT_TYPES.include?(type)
    end

    def valid_accept?(value)
      value.split(",").compact.collect(&:strip).all? { |v| valid_content_type?(v) }
    end

    def content_type_header
      CONTENT_TYPES.first + '; profile="' + ACTIVITY_STREAMS_CONTEXT + '"'
    end

    def public_collection_id
      PUBLIC_COLLECTION_IDS.first
    end

    def resolve_icon_url(value)
      return nil if value.nil?
      return value if value.is_a?(String)
      return value["url"] if value.is_a?(Hash)
      value.first["url"] if value.is_a?(Array)
    end

    def publicly_addressed?(json)
      (addressed_to(json) & PUBLIC_COLLECTION_IDS).any?
    end

    def addressed_to(json)
      ([*json[:to]] + [*json[:cc]] + [*json[:audience]]).uniq.compact
    end

    def generate_key
      SecureRandom.hex(16)
    end

    def generate_id(type)
      json_ld_id(type, generate_key)
    end

    def address_json(json, args = {})
      object_keys = %w[object]
      item_keys = %w[items orderedItems]

      json["to"] = args[:to]
      json["cc"] = args[:cc] if args[:cc]

      object_keys.each do |object_key|
        json[object_key] = address_json(json[object_key], args) if json[object_key].present?
      end

      item_keys.each do |item_key|
        if json[item_key].present?
          json[item_key] = json[item_key].map { |item| address_json(item, args) }
        end
      end

      json
    end

    def address_to_actor_id(audience)
      audience.chomp("#followers").chomp("/followers")
    end

    module_function :validate_json_ld
    module_function :parse_json_ld
    module_function :format_jsonld
    module_function :required_contexts?
    module_function :required_properties?
    module_function :resolve_id
    module_function :resolve_object
    module_function :request_object
    module_function :json_ld_id
    module_function :valid_content_type?
    module_function :valid_accept?
    module_function :content_type_header
    module_function :public_collection_id
    module_function :resolve_icon_url
    module_function :publicly_addressed?
    module_function :addressed_to
    module_function :generate_key
    module_function :generate_id
    module_function :domain_from_id
    module_function :address_json
    module_function :address_to_actor_id
  end
end
