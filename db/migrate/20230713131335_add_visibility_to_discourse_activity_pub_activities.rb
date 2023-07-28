# frozen_string_literal: true
class AddVisibilityToDiscourseActivityPubActivities < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_activity_pub_activities, :visibility, :integer, default: 2

    execute "UPDATE discourse_activity_pub_activities SET visibility = 1"

    execute <<~SQL
      INSERT INTO post_custom_fields(post_id, name, value, created_at, updated_at)
      SELECT post_id, 'activity_pub_visibility', 'private', created_at, updated_at
      FROM post_custom_fields
      WHERE name = 'activity_pub_published_at' AND value IS NOT NULL
    SQL

    sql = <<~SQL
      INSERT INTO category_custom_fields(category_id, name, value, created_at, updated_at)
      SELECT category_id, 'activity_pub_default_visibility', 'private', created_at, updated_at
      FROM category_custom_fields
      WHERE name = 'activity_pub_enabled' AND value IN(:custom_fields_true)
    SQL

    DB.exec(sql, custom_fields_true: HasCustomFields::Helpers::CUSTOM_FIELD_TRUE)
  end

  def down
    remove_column :discourse_activity_pub_activities, :visibility
    execute "DELETE FROM post_custom_fields WHERE name = 'activity_pub_visibility'"
    execute "DELETE FROM category_custom_fields WHERE name = 'activity_pub_default_visibility'"
  end
end
