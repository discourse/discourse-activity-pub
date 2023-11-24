# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubProcess < ::Jobs::Base
    def execute(args)
      @args = args
      ap_activity = DiscourseActivityPub::AP::Activity.factory(@args[:json])

      if ap_activity && ap_activity.respond_to?(:process)
        ap_activity.target = @args[:target] if @args[:target].present?
        log_process_start
        ap_activity.process
      end
    end

    protected

    def log_process_start
      return unless SiteSetting.activity_pub_verbose_logging
      prefix = I18n.t("discourse_activity_pub.process.info.process_started", target: @args[:target])
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{JSON.generate(@args[:json])}")
    end
  end
end