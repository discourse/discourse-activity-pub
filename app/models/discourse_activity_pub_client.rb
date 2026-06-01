# frozen_string_literal: true

class DiscourseActivityPubClient < ActiveRecord::Base
  has_many :authorizations, class_name: "DiscourseActivityPubAuthorization"

  ALLOWED_CREDENTIAL_KEYS = {
    mastodon: %w[client_id client_secret access_token],
  }

  def self.auth_types
    @auth_types ||= Enum.new(mastodon: 2)
  end

  validates :auth_type,
            inclusion: {
              in: DiscourseActivityPubClient.auth_types.values,
              message: "%{value} is not a valid auth_type",
            }
  validate :verify_credentials

  def mastodon?
    auth_type === self.class.auth_types[:mastodon]
  end

  def auth_type_name
    auth_type && self.class.auth_types[auth_type]
  end

  protected

  def verify_credentials
    if !self.credentials
      return(
        errors.add(
          :credentials,
          I18n.t(
            "activerecord.errors.models.discourse_activity_pub_client.attributes.credentials.required",
          ),
        )
      )
    end

    allowed_credential_keys = ALLOWED_CREDENTIAL_KEYS[auth_type_name]
    if !allowed_credential_keys ||
         self.credentials.keys.any? { |key| allowed_credential_keys.exclude?(key) }
      errors.add(
        :credentials,
        I18n.t(
          "activerecord.errors.models.discourse_activity_pub_client.attributes.credentials.invalid",
        ),
      )
    end
    true
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_clients
#
#  id          :bigint           not null, primary key
#  auth_type   :integer          not null
#  credentials :json             not null
#  domain      :string(1000)     not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  unique_activity_pub_client_auth_domains  (auth_type,domain) UNIQUE
#
