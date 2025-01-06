# frozen_string_literal: true

class ActivityPubSignedRequestsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    SiteSetting.activity_pub_require_signed_requests
  end

  def error_message
    I18n.t("site_settings.errors.signed_requests_required")
  end
end
