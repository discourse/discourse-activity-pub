# frozen_string_literal: true

module DiscourseActivityPub
  class Request
    include JsonLd

    SUPPORTED_SCHEMES = %w(http https)
    SUCCESS_CODES = [200, 201, 202]
    REDIRECT_CODES = [301, 302, 307, 308]

    attr_accessor :url,
                  :headers,
                  :body,
                  :expects,
                  :middlewares

    def initialize(uri: "", headers: {}, body: nil)
      @url = Addressable::URI.parse(uri).normalize
      @headers = headers
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
      @headers.merge!({ 'Content-Type' => content_type_header })
      @body = @body.to_json
      @expects = SUCCESS_CODES

      perform(:post) ? true : false
    end

    def perform(verb)
      return unless self.class.valid_url?(url)

      options = {
        headers: headers
      }

      options[:expects] = expects if expects.present?
      options[:middlewares] = middlewares if middlewares.present?
      options[:body] = body if body.present?

      Excon.send(verb, url, options)
    rescue Excon::Error
      nil
    end

    def self.valid_url?(url)
      parsed = Addressable::URI.parse(url)
      SUPPORTED_SCHEMES.include?(parsed.scheme)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def self.get_json_ld(uri: "", headers: {})
      self.new(uri: uri, headers: headers).get_json_ld
    end

    def self.post_json_ld(uri: "", headers: {}, body: nil)
      self.new(uri: uri, headers: headers, body: body).post_json_ld
    end
  end
end
