# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubPublish < ::Jobs::Base
    def execute(args)
      topic = Topic.find_by(id: args[:topic_id])
      return unless topic

      result = DiscourseActivityPub::Bulk::Publish.perform(topic_id: topic.id)
      topic.reload.activity_pub_publish_state if result.finished
    end
  end
end
