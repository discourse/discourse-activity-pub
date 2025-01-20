# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ObjectHelpers
      extend ActiveSupport::Concern

      def get_published_at
        self.published_at ?
          self.published_at.to_time.utc.iso8601 :
          Time.now.utc.iso8601
      end

      def get_delivered_at
        Time.now.utc.iso8601
      end
    end
  end
end
