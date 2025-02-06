# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubProcess < ::Jobs::Base
    def execute(args)
      @args = args

      DistributedMutex.synchronize("activity_pub_process_#{process_id}", validity: 2.minutes) do
        ap_activity = DiscourseActivityPub::AP::Activity.factory(@args[:json])

        if ap_activity && ap_activity.respond_to?(:process)
          ap_activity.delivered_to << @args[:delivered_to] if @args[:delivered_to].present?
          log_process_start
          ap_activity.process
        end
      end
    end

    protected

    def process_id
      @process_id ||=
        begin
          identifier =
            DiscourseActivityPub::JsonLd.base_object_id(@args[:json]) ||
              identifier = @args[:json].to_s if identifier.blank? || !identifier.is_a?(String)
          Digest::MD5.hexdigest(identifier)
        end
    end

    def log_process_start
      DiscourseActivityPub::Logger.info(
        I18n.t(
          "discourse_activity_pub.process.info.processing_json",
          delivered_to: @args[:delivered_to],
        ),
      )
    end
  end
end
