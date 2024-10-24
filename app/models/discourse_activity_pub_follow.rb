# frozen_string_literal: true

class DiscourseActivityPubFollow < ActiveRecord::Base
  belongs_to :follower, class_name: "DiscourseActivityPubActor"
  belongs_to :followed, class_name: "DiscourseActivityPubActor"

  def followed_at
    created_at
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_follows
#
#  id          :bigint           not null, primary key
#  follower_id :bigint           not null
#  followed_id :bigint           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Foreign Keys
#
#  fk_rails_...  (followed_id => discourse_activity_pub_actors.id)
#  fk_rails_...  (follower_id => discourse_activity_pub_actors.id)
#
