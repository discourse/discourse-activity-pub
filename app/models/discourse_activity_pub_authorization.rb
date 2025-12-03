# frozen_string_literal: true

class DiscourseActivityPubAuthorization < ActiveRecord::Base
  belongs_to :user
  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :client, class_name: "DiscourseActivityPubClient"

  scope :active, -> { where("actor_id IS NOT NULL") }
end

# == Schema Information
#
# Table name: discourse_activity_pub_authorizations
#
#  id         :bigint           not null, primary key
#  token      :string(1000)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  actor_id   :bigint
#  client_id  :bigint
#  user_id    :integer          not null
#
# Indexes
#
#  unique_activity_pub_authorization_user_actors  (user_id,actor_id) UNIQUE
#
