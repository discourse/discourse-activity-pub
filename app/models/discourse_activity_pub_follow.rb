# frozen_string_literal: true

class DiscourseActivityPubFollow < ActiveRecord::Base
  belongs_to :follower, class_name: "DiscourseActivityPubActor"
  belongs_to :followed, class_name: "DiscourseActivityPubActor"
end
