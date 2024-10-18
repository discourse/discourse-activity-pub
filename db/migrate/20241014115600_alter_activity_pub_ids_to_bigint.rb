# frozen_string_literal: true

class AlterActivityPubIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :discourse_activity_pub_activities, :actor_id, :bigint
    change_column :discourse_activity_pub_activities, :object_id, :bigint
    change_column :discourse_activity_pub_objects, :collection_id, :bigint
    change_column :discourse_activity_pub_follows, :follower_id, :bigint
    change_column :discourse_activity_pub_follows, :followed_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
