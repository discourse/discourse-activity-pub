# frozen_string_literal: true
class AddUniqueIndexToDiscourseActivityPubFollows < ActiveRecord::Migration[8.0]
  INDEX_NAME = "idx_discourse_activity_pub_follows_unique_pair"

  def up
    execute <<~SQL
      DELETE FROM discourse_activity_pub_follows
      WHERE id IN (
        SELECT id
        FROM (
          SELECT
            id,
            row_number() OVER (
              PARTITION BY follower_id, followed_id
              ORDER BY id
            ) AS row_number
          FROM discourse_activity_pub_follows
        ) duplicates
        WHERE duplicates.row_number > 1
      )
    SQL

    add_index :discourse_activity_pub_follows,
              %i[follower_id followed_id],
              unique: true,
              name: INDEX_NAME
  end

  def down
    remove_index :discourse_activity_pub_follows, name: INDEX_NAME
  end
end
