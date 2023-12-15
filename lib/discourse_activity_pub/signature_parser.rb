# frozen_string_literal: true

# Based on 99designs/http-signatures-ruby/lib/http_signatures/signature_parameters_parser.rb
# See also mastodon/mastodon/app/controllers/concerns/signature_verification.rb

module DiscourseActivityPub
  class SignatureParser
    class Error < StandardError
    end

    def initialize(string)
      @string = string
    end

    def parse
      Hash[array_of_pairs]
    end

    private

    def array_of_pairs
      segments.map { |segment| pair(segment) }
    end

    def segments
      @string.split(",")
    end

    def pair(segment)
      match = segment_pattern.match(segment)
      raise Error, "unparseable segment: #{segment}" if match.nil?
      match.captures
    end

    def segment_pattern
      /\A(keyId|algorithm|headers|signature|created|expires)="(.*)"\z/
    end
  end
end
