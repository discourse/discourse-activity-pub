# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ObjectHelpers
      extend ActiveSupport::Concern

      def tombstone!
        update(
          ap_former_type: self.ap_type,
          ap_type: AP::Object::Tombstone.type,
          deleted_at: Time.now.utc.iso8601,
        )
      end

      def restore_from_tombstone!
        update(
          ap_type: self.model.activity_pub_default_object_type,
          ap_former_type: nil,
          deleted_at: nil,
        )
      end

      def tombstone_objects!
        sql = <<~SQL
        UPDATE discourse_activity_pub_objects
        SET ap_former_type = discourse_activity_pub_objects.ap_type,
            ap_type = :ap_type,
            deleted_at = :deleted_at
        WHERE attributed_to_id = :actor_ap_id
        SQL
        DB.exec(
          sql,
          actor_ap_id: self.ap_id,
          ap_type: AP::Object::Tombstone.type,
          deleted_at: Time.now.utc.iso8601,
        )
      end

      def restore_objects_from_tombstone!
        sql = <<~SQL
        UPDATE discourse_activity_pub_objects
        SET ap_former_type = null,
            ap_type = :ap_type,
            deleted_at = null
        WHERE attributed_to_id = :actor_ap_id
        SQL
        DB.exec(sql, actor_ap_id: self.ap_id, ap_type: self.model.activity_pub_default_object_type)
      end
    end
  end
end
