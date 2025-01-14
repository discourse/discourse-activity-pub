# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubLogRotate < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if !SiteSetting.activity_pub_enabled

      DiscourseActivityPubLog.where(
        "created_at < ?",
        SiteSetting.activity_pub_logs_max_days_old.days.ago,
      ).destroy_all
    end
  end
end
