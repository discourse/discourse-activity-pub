# frozen_string_literal: true

class DiscourseActivityPubFollow < ActiveRecord::Base
  belongs_to :follower, class_name: "DiscourseActivityPubActor"
  belongs_to :followed, class_name: "DiscourseActivityPubActor"
end

# == Schema Information
#
# Table name: discourse_activity_pub_follows
#
#  id          :bigint           not null, primary key
#  follower_id :integer          not null
#  followed_id :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Foreign Keys
#
#  fk_rails_...  (followed_id => discourse_activity_pub_actors.id)
#  fk_rails_...  (follower_id => discourse_activity_pub_actors.id)
#
