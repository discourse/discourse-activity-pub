# frozen_string_literal: true
class CreateDiscourseActivityPubAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_activity_pub_attachments do |t|
      t.string :ap_type, null: false
      t.bigint :object_id, null: false
      t.string :object_type, null: false
      t.string :url
      t.string :name
      t.string :media_type, limit: 200

      t.timestamps
    end
  end
end
