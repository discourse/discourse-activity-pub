# frozen_string_literal: true

class DiscourseActivityPub::AP::SharedInboxesController < DiscourseActivityPub::AP::ObjectsController
  requires_plugin DiscourseActivityPub::PLUGIN_NAME

  before_action :validate_json
  before_action :ensure_verified_signature, if: :require_signed_requests?

  def create
    process_json
    head 202
  end

  protected

  def rate_limit
    limit = SiteSetting.activity_pub_rate_limit_post_to_inbox_per_minute
    RateLimiter.new(
      nil,
      "activity-pub-inbox-post-min-#{request.remote_ip}",
      limit,
      1.minute,
    ).performed!
  end

  def process_json
    Jobs.enqueue(Jobs::DiscourseActivityPub::Process, json: @json)
  end

  def validate_json
    @json = validate_json_ld(@raw_body)

    if @json
      DiscourseActivityPub::Logger.info(
        I18n.t(
          "discourse_activity_pub.process.info.received_json",
          delivered_to: I18n.t("discourse_activity_pub.process.info.shared_inbox"),
        ),
        json: @json,
      )
    else
      render_activity_pub_error("json_not_valid", 422)
    end
  end
end
