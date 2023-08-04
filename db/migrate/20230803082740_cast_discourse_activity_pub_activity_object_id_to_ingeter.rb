# frozen_string_literal: true
class CastDiscourseActivityPubActivityObjectIdToIngeter < ActiveRecord::Migration[7.0]
  def up
    change_column :discourse_activity_pub_activities, :object_id, :integer, using: 'object_id::integer'
  end

  def down
    change_column :discourse_activity_pub_activities, :object_id, :string, using: 'object_id::varchar'
  end
end
