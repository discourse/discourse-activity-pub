# frozen_string_literal: true
class CreateDiscourseActivityPubActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_activity_pub_activities do |t|
      t.string :ap_id, null: false, index: true, unique: true
      t.string :ap_key, unique: true
      t.string :ap_type, null: false
      t.boolean :local
      t.integer :actor_id, null: false
      t.string :object_id
      t.string :object_type
      t.string :summary

      t.timestamps
    end

    add_foreign_key :discourse_activity_pub_activities, :discourse_activity_pub_actors, column: :actor_id
  end
end
