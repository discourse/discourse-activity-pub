# frozen_string_literal: true
class CreateDiscourseActivityPubObjects < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_activity_pub_objects do |t|
      t.string :uid, null: false, index: true, unique: true
      t.string :ap_type, null: false
      t.integer :model_id
      t.string :model_type
      t.string :content

      t.timestamps
    end
  end
end
