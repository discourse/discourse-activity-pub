# frozen_string_literal: true
class CreateDiscourseActivityPubActors < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_activity_pub_actors do |t|
      t.string :uid, null: false, index: true, unique: true
      t.string :domain, null: false
      t.string :ap_type, null: false
      t.string :inbox
      t.string :outbox
      t.string :preferred_username
      t.string :name
      t.integer :model_id
      t.string :model_type

      t.timestamps
    end
  end
end
