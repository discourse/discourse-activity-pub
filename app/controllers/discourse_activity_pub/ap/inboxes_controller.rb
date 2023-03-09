# frozen_string_literal: true

class DiscourseActivityPub::AP::InboxesController < DiscourseActivityPub::AP::CollectionsController
  include DiscourseActivityPub::JsonLd

  before_action :validate_headers

  def create
    @json = validate_json_ld(request.body.read)

    if @json
      process_json
      head 202
    else
      handle_invalid_json
    end
  end

  protected

  def rate_limit
    limit = SiteSetting.activity_pub_rate_limit_post_to_inbox_per_minute
    RateLimiter.new(nil, "activity-pub-inbox-post-min-#{request.remote_ip}", limit, 1.minute).performed!
  end

  def validate_headers
    handle_invalid_json unless valid_content_type?(request.headers['Content-Type'])
  end

  def process_json
    Jobs.enqueue(:discourse_activity_pub_process, json: @json)
  end

  def handle_invalid_json
    render_json_error I18n.t("discourse_activity_pub.activity.error.json_not_valid"), status: 422
  end
end
