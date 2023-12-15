# frozen_string_literal: true

class DiscourseActivityPub::AP::InboxesController < DiscourseActivityPub::AP::ActorsController
  def create
    @json = validate_json_ld(request.body.read)

    if @json
      process_json
      head 202
    else
      render_activity_pub_error("json_not_valid", 422)
    end
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
    Jobs.enqueue(:discourse_activity_pub_process, json: @json, delivered_to: @actor.ap_id)
  end
end
