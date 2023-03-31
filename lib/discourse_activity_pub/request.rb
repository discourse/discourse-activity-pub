# frozen_string_literal: true

module DiscourseActivityPub
  class Request
    include JsonLd

    SUPPORTED_SCHEMES = %w(http https)
    SUCCESS_CODES = [200, 201, 202]
    REDIRECT_CODES = [301, 302, 307, 308]
    REQUEST_TARGET = '(request-target)'
    SIGNAUTRE_ALGORITHM = 'rsa-sha256'

    attr_accessor :uri,
                  :headers,
                  :body,
                  :expects,
                  :middlewares,
                  :actor

    def initialize(actor_id: nil, uri: "", headers: {}, body: nil)
      @actor = DiscourseActivityPubActor.find_by(id: actor_id) if actor_id
      @uri = Request.parse(uri)
      @headers = default_headers.merge(headers)
      @body = body
    end

    def get_json_ld
      @headers.merge!({ 'Accept' => content_type_header })
      @expects = SUCCESS_CODES + REDIRECT_CODES
      @middlewares = Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower]

      response = perform(:get)
      response ? validate_json_ld(response.body) : nil
    end

    def post_json_ld
      @body = @body.to_json
      @headers.merge!({
        'Digest' => "SHA-256=#{Digest::SHA256.base64digest(@body)}",
        'Content-Type' => content_type_header
      })
      @expects = SUCCESS_CODES

      perform(:post) ? true : false
    end

    def perform(verb)
      return unless SUPPORTED_SCHEMES.include?(uri.scheme)

      headers[REQUEST_TARGET] = "#{verb} #{uri.path}"
      headers['Signature'] = self.class.build_signature(
        key_id: signature_key_id(actor),
        keypair: actor.keypair,
        headers: headers
      ) if sign_request?

      options = {
        headers: headers
      }

      options[:expects] = expects if expects.present?
      options[:middlewares] = middlewares if middlewares.present?
      options[:body] = body if body.present?

      Excon.send(verb, uri.to_s, options)
    rescue Excon::Error
      nil
    end

    def default_headers
      {
        'Host' => uri.host,
        'Date' => Time.now.utc.httpdate
      }
    end

    def sign_request?
      actor.present? && actor.keypair.present?
    end

    def self.build_signature(key_id: nil, keypair: nil, headers: {}, custom_params: {})
      headers = headers.without('User-Agent', 'Accept-Encoding', 'Content-Type', 'Accept')
      headers_str = headers.map { |key, value| "#{key.downcase}: #{value}" }.join("\n")
      signed_headers = keypair.sign(OpenSSL::Digest.new('SHA256'), headers_str)
      signature = Base64.strict_encode64(signed_headers)
      params = {
        "keyId" => key_id,
        "algorithm" => SIGNAUTRE_ALGORITHM,
        "headers" => headers.keys.join(' ').downcase,
        "signature" => signature
      }.merge(custom_params)
      params
        .select { |key, value| value.present? }
        .map{ |key, value| "#{key}=\"#{value}\"" }
        .join(',')
    end

    def self.parse(uri)
      Addressable::URI.parse(uri)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def self.valid_url?(url)
      parsed = Addressable::URI.parse(url)
      SUPPORTED_SCHEMES.include?(parsed.scheme)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def self.domain_from_uri(uri)
      uri && Addressable::URI.parse(uri).domain
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def self.get_json_ld(uri: "", headers: {})
      self.new(uri: uri, headers: headers).get_json_ld
    end

    def self.post_json_ld(actor_id: nil, uri: "", headers: {}, body: nil)
      body[:to] = uri
      self.new(actor_id: nil, uri: uri, headers: headers, body: body).post_json_ld
    end
  end
end
