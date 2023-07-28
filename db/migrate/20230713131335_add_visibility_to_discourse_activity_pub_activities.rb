# frozen_string_literal: true
class AddVisibilityToDiscourseActivityPubActivities < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_activities, :visibility, :integer, default: 2
  end
end
