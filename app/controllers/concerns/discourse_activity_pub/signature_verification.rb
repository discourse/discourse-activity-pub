# frozen_string_literal: true

# Based on mastodon/mastodon/app/controllers/concerns/signature_verification.rb

module DiscourseActivityPub
  module SignatureVerification
    extend ActiveSupport::Concern

    EXPIRATION_WINDOW_LIMIT = 12.hours
    CLOCK_SKEW_MARGIN = 1.hour
    SUPPORTED_ALOGRITHMS = %w[rsa-sha256 hs2019]

    class Error < StandardError
      attr_reader :opts

      def initialize(opts)
        super
        @opts = opts
      end
    end

    def ensure_verified_signature
      unless signed_request_actor
        render_activity_pub_error(
          signature_verification_failure_reason,
          signature_verification_failure_code,
          signature_verification_failure_opts,
        )
      end
    end

    def signed_request?
      request.headers["Signature"].present?
    end

    def signature_verification_failure_reason
      @signature_verification_failure_reason
    end

    def signature_verification_failure_opts
      @signature_verification_failure_opts || {}
    end

    def signature_verification_failure_code
      @signature_verification_failure_code || 401
    end

    def signed_request_actor
      return @signed_request_actor if defined?(@signed_request_actor)

      raise Error, "not_signed" unless signed_request?
      raise Error, "missing_signature_params" if missing_required_signature_parameters?
      if SUPPORTED_ALOGRITHMS.exclude?(signature_algorithm)
        raise Error, "unsupported_signature_algorithm"
      end
      raise Error, "stale_request" unless matches_time_window?

      verify_signature_strength!
      verify_body_digest!

      actor = actor_from_key_id(signature_params["keyId"])
      raise Error.new(key_id: signature_params["keyId"]), "actor_not_found_for_key" if !actor

      signature = Base64.decode64(signature_params["signature"])
      return actor if verify_signature(actor, signature)

      actor.refresh_remote!
      return actor if verify_signature(actor.reload, signature)

      raise Error.new(id: actor.ap_id), "signature_verification_failed"
    rescue Error => e
      @signature_verification_failure_reason = e.message
      @signature_verification_failure_opts = e.opts
      @signed_request_actor = nil
    end

    private

    def signature_params
      @signature_params ||= SignatureParser.new(request.headers["Signature"]).parse
    rescue SignatureParser::Error
      raise Error, "signature_parse_failed"
    end

    def signature_algorithm
      signature_params.fetch("algorithm", "hs2019")
    end

    def signed_headers
      signature_params
        .fetch("headers", signature_algorithm == "hs2019" ? "(created)" : "date")
        .downcase
        .split(" ")
    end

    def verify_signature_strength!
      if signed_headers.exclude?("date") && signed_headers.exclude?("(created)")
        raise Error, "date_must_be_signed"
      end
      if signed_headers.exclude?(Request::REQUEST_TARGET_HEADER) &&
           signed_headers.exclude?("digest")
        raise Error, "digest_must_be_signed"
      end
      raise Error, "host_must_be_signed_on_get" if request.get? && !signed_headers.include?("host")
      if request.post? && !signed_headers.include?("digest")
        raise Error, "digest_must_be_signed_on_post"
      end
    end

    def verify_body_digest!
      return if signed_headers.exclude?("digest")
      raise Error, "digest_header_missing" unless request.headers.key?("Digest")

      digests =
        request.headers["Digest"]
          .split(",")
          .map { |digest| digest.split("=", 2) }
          .map { |key, value| [key.downcase, value] }
      sha256 = digests.assoc("sha-256")
      if sha256.nil?
        raise Error.new(algorithms: digests.map(&:first).join(", ")),
              "invalid_digest_header_algorithm"
      end

      return if body_digest == sha256[1]

      digest_size =
        begin
          Base64.strict_decode64(sha256[1].strip).length
        rescue ArgumentError
          raise Error.new(digest: sha256[1]), "invalid_digest_base64"
        end

      raise Error.new(digest: sha256[1]), "invalid_digest_sha256" if digest_size != 32
      raise Error.new(computed: body_digest, digest: sha256[1]), "invalid_digest"
    end

    def verify_signature(actor, signature)
      unless actor.keypair.public_key.verify(
               OpenSSL::Digest.new("SHA256"),
               signature,
               signed_string,
             )
        return false
      end
      @signed_request_actor = actor
      @signed_request_actor
    rescue OpenSSL::PKey::RSAError
      false
    end

    def signed_string
      @signed_string ||=
        begin
          signed_headers
            .map do |signed_header|
              if signed_header == Request::REQUEST_TARGET_HEADER
                "#{Request::REQUEST_TARGET_HEADER}: #{request.method.downcase} #{request.path}"
              elsif signed_header == "(created)" || signed_header == "(expires)"
                _type = signed_header.delete("()")
                if signature_params[_type].blank?
                  raise Error.new(header: _type), "invalid_signature_pseudo_header"
                end
                "(#{_type}): #{signature_params[_type]}"
              elsif signed_header.downcase == "host"
                value =
                  if Rails.env.development?
                    request.headers["HTTP_X_FORWARDED_HOST"]
                  else
                    request.headers[to_header_name(signed_header)]
                  end
                "#{signed_header}: #{value}"
              else
                "#{signed_header}: #{request.headers[to_header_name(signed_header)]}"
              end
            end
            .join("\n")
        end
    end

    def matches_time_window?
      created_time = nil
      expires_time = nil

      begin
        if signature_algorithm == "hs2019" && signature_params["created"].present?
          created_time = Time.at(signature_params["created"].to_i).utc
        elsif request.headers["Date"].present?
          created_time = Time.httpdate(request.headers["Date"]).utc
        end

        expires_time = Time.at(signature_params["expires"].to_i).utc if signature_params[
          "expires"
        ].present?
      rescue ArgumentError => e
        raise Error.new(reason: e.message), "invalid_date_header"
      end

      expires_time ||= created_time + 5.minutes unless created_time.nil?
      expires_time = [
        expires_time,
        created_time + EXPIRATION_WINDOW_LIMIT,
      ].min unless created_time.nil?

      return false if created_time.present? && created_time > Time.now.utc + CLOCK_SKEW_MARGIN
      return false if expires_time.present? && Time.now.utc > expires_time + CLOCK_SKEW_MARGIN

      true
    end

    def body_digest
      @body_digest ||= Digest::SHA256.base64digest(@raw_body)
    end

    def to_header_name(name)
      name.split("-").map(&:capitalize).join("-")
    end

    def missing_required_signature_parameters?
      signature_params["keyId"].blank? || signature_params["signature"].blank?
    end

    def actor_from_key_id(key_id)
      ap_id = key_id.split("#").first
      domain =
        (
          if ap_id.start_with?("acct:")
            ap_id.split("@").last
          else
            DiscourseActivityPub::URI.domain_from_uri(ap_id)
          end
        )

      unless domain_allowed?(domain)
        @signature_verification_failure_code = 403
        return
      end

      if ap_id.start_with?("acct:")
        actor = DiscourseActivityPubActor.find_by_handle(ap_id.gsub(/\Aacct:/, ""), local: false)
      else
        actor = DiscourseActivityPubActor.find_by(ap_id: ap_id)

        if !actor
          ap_actor = AP::Actor.resolve_and_store(ap_id)
          actor = ap_actor.stored if ap_actor
        end
      end

      actor
    end
  end
end
