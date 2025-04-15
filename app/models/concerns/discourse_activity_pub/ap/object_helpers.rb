# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ObjectHelpers
      extend ActiveSupport::Concern

      def tombstone!
        self.update(
          ap_former_type: self.ap_type,
          ap_type: AP::Object::Tombstone.type,
          deleted_at: Time.now.utc.iso8601,
        )
      end

      def restore_from_tombstone!
        self.update(
          ap_type: self.model.activity_pub_default_object_type,
          ap_former_type: nil,
          deleted_at: nil,
        )
      end
    end
  end
end
