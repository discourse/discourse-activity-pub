# frozen_string_literal: true
class AddAttributedToToDiscourseActivityPubObjects < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_activity_pub_objects, :attributed_to_id, :string

    # We are migrating post object attribution in full_topic categories because we're handling
    # first_post object attribution in the model to give us more flexibility (i.e. it may change)
    execute <<SQL
  UPDATE discourse_activity_pub_objects
  SET attributed_to_id = post_actors.ap_id
  FROM (
    SELECT
      posts.id,
      discourse_activity_pub_actors.ap_id
    FROM discourse_activity_pub_actors
    JOIN users ON users.id = discourse_activity_pub_actors.model_id
    JOIN posts ON posts.user_id = users.id
    JOIN topics ON topics.id = posts.topic_id
    JOIN categories ON categories.id = topics.category_id
    JOIN category_custom_fields
      ON category_custom_fields.category_id = categories.id
      AND category_custom_fields.value = 'full_topic'
    GROUP BY posts.id, discourse_activity_pub_actors.ap_id
  ) as post_actors
  WHERE post_actors.id = discourse_activity_pub_objects.model_id
SQL
  end

  def down
    add_column :discourse_activity_pub_objects, :attributed_to_id
  end
end
