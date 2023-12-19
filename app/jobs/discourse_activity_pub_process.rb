# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubProcess < ::Jobs::Base
    def execute(args)
      @args = args
      ap_activity = DiscourseActivityPub::AP::Activity.factory(@args[:json])

      if ap_activity && ap_activity.respond_to?(:process)
        ap_activity.delivered_to << @args[:delivered_to] if @args[:delivered_to].present?
        log_process_start
        ap_activity.process
      end
    end

    protected

    def log_process_start
      DiscourseActivityPub::Logger.info(
        I18n.t("discourse_activity_pub.process.info.process_started",
          delivered_to: @args[:delivered_to]
        ),
        json: @args[:json]
      )
    end
  end
end