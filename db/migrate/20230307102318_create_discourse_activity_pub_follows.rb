# frozen_string_literal: true
class CreateDiscourseActivityPubFollows < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_activity_pub_follows do |t|
      t.integer :follower_id, null: false
      t.integer :followed_id, null: false

      t.timestamps
    end

    add_foreign_key :discourse_activity_pub_follows,
                    :discourse_activity_pub_actors,
                    column: :follower_id
    add_foreign_key :discourse_activity_pub_follows,
                    :discourse_activity_pub_actors,
                    column: :followed_id
  end
end
