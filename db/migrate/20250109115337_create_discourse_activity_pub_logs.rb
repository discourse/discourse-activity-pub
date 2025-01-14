# frozen_string_literal: true
class CreateDiscourseActivityPubLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_activity_pub_logs do |t|
      t.integer :level
      t.string :message
      t.json :json

      t.timestamps
    end
  end
end
