# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubProcess < ::Jobs::Base
    def execute(args)
      ap_activity = DiscourseActivityPub::AP::Activity.factory(args[:json])
      ap_activity.process if ap_activity
    end
  end
end
