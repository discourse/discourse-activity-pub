# frozen_string_literal: true
class AddInReplyToToDiscourseActivityPubObject < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_objects, :in_reply_to, :string
  end
end
