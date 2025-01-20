# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubPublish < ::Jobs::Base
    def execute(args)
      DiscourseActivityPub::Bulk::Publish.perform(topic_id: args[:topic_id])
    end
  end
end
