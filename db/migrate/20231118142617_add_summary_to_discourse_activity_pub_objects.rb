# frozen_string_literal: true
class AddSummaryToDiscourseActivityPubObjects < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_objects, :summary, :string
  end
end
