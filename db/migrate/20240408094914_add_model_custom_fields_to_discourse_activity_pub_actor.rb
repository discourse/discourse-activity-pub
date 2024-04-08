# frozen_string_literal: true
class AddModelCustomFieldsToDiscourseActivityPubActor < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_activity_pub_actors, :enabled, :boolean
    add_column :discourse_activity_pub_actors, :default_visibility, :string
    add_column :discourse_activity_pub_actors, :publication_type, :string
    add_column :discourse_activity_pub_actors, :post_object_type, :string

    execute <<SQL
      UPDATE discourse_activity_pub_actors
      SET enabled = ccf.value::boolean
      FROM (
        SELECT
          category_id,
          value
        FROM category_custom_fields
        WHERE name = 'activity_pub_enabled'
      ) as ccf
      WHERE ccf.category_id = discourse_activity_pub_actors.model_id
SQL

    execute <<SQL
      UPDATE discourse_activity_pub_actors
      SET default_visibility = ccf.value
      FROM (
        SELECT
          category_id,
          value
        FROM category_custom_fields
        WHERE name = 'activity_pub_default_visibility'
      ) as ccf
      WHERE ccf.category_id = discourse_activity_pub_actors.model_id
SQL

    execute <<SQL
      UPDATE discourse_activity_pub_actors
      SET publication_type = ccf.value
      FROM (
        SELECT
          category_id,
          value
        FROM category_custom_fields
        WHERE name = 'activity_pub_publication_type'
      ) as ccf
      WHERE ccf.category_id = discourse_activity_pub_actors.model_id
SQL

    execute <<SQL
      UPDATE discourse_activity_pub_actors
      SET post_object_type = ccf.value
      FROM (
        SELECT
          category_id,
          value
        FROM category_custom_fields
        WHERE name = 'activity_pub_post_object_type'
      ) as ccf
      WHERE ccf.category_id = discourse_activity_pub_actors.model_id
SQL

  end

  def down
    remove_column :discourse_activity_pub_actors, :enabled
    remove_column :discourse_activity_pub_actors, :default_visibility
    remove_column :discourse_activity_pub_actors, :publication_type
    remove_column :discourse_activity_pub_actors, :post_object_type
  end
end
