# frozen_string_literal: true

class DiscourseActivityPubClient < ActiveRecord::Base
  has_many :authorizations, class_name: "DiscourseActivityPubAuthorization"

  ALLOWED_CREDENTIAL_KEYS = {
    discourse: %w[public_key private_key],
    mastodon: %w[client_id client_secret],
  }

  DISCOURSE_SCOPE = "discourse-activity-pub:read"

  def self.auth_types
    @auth_types ||= Enum.new(discourse: 1, mastodon: 2)
  end

  validates :auth_type,
            inclusion: {
              in: DiscourseActivityPubClient.auth_types.values,
              message: "%{value} is not a valid auth_type",
            }
  validate :verify_credentials

  def discourse?
    auth_type === self.class.auth_types[:discourse]
  end

  def mastodon?
    auth_type === self.class.auth_types[:mastodon]
  end

  def auth_type_name
    auth_type && self.class.auth_types[auth_type]
  end

  def self.update_scope_settings
    allowed_client_scopes = SiteSetting.allow_user_api_key_client_scopes.split("|")
    allowed_key_scopes = SiteSetting.allow_user_api_key_scopes.split("|")
    client_scope_allowed = allowed_client_scopes.include?(DISCOURSE_SCOPE)
    key_scope_allowed = allowed_key_scopes.include?(DISCOURSE_SCOPE)

    if SiteSetting.activity_pub_enabled
      if !client_scope_allowed
        allowed_client_scopes.push(DISCOURSE_SCOPE)
        SiteSetting.allow_user_api_key_client_scopes = allowed_client_scopes.join("|")
      end
      if !key_scope_allowed
        allowed_key_scopes.push(DISCOURSE_SCOPE)
        SiteSetting.allow_user_api_key_scopes = allowed_key_scopes.join("|")
      end
    else
      if client_scope_allowed
        allowed_client_scopes.delete(DISCOURSE_SCOPE)
        SiteSetting.allow_user_api_key_client_scopes = allowed_client_scopes.join("|")
      end
      if key_scope_allowed
        allowed_key_scopes.delete(DISCOURSE_SCOPE)
        SiteSetting.allow_user_api_key_scopes = allowed_key_scopes.join("|")
      end
    end
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

    if self.credentials.keys.any? { |key| ALLOWED_CREDENTIAL_KEYS[auth_type_name].exclude?(key) }
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
# Table name: discourse_activity_pub_authorization_clients
#
#  id          :bigint           not null, primary key
#  domain      :string
#  auth_type   :integer
#  private_key :text
#  public_key  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
