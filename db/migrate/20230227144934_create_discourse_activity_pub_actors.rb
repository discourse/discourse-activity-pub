# frozen_string_literal: true
class CreateDiscourseActivityPubActors < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_activity_pub_actors do |t|
      t.string :ap_id, null: false, index: true, unique: true
      t.string :ap_key, unique: true
      t.string :ap_type, null: false
      t.string :domain
      t.boolean :local
      t.boolean :available, default: true
      t.string :inbox
      t.string :outbox
      t.string :username
      t.string :name
      t.integer :model_id
      t.string :model_type
      t.text :private_key
      t.text :public_key

      t.timestamps
    end
  end
end
