# frozen_string_literal: true
class AddFullTopicSupportToDiscourseActivityPubObject < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_objects, :in_reply_to, :string
    add_column :discourse_activity_pub_objects, :published_at, :datetime
    add_column :discourse_activity_pub_objects, :url, :string
    add_column :discourse_activity_pub_objects, :domain, :string
  end
end