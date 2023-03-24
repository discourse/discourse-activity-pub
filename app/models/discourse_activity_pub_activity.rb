# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::ActivityValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  after_create :deliver, if: Proc.new { ap&.composed? }

  def deliver
    ap.stored = self
    ap.deliver
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_activities
#
#  id          :bigint           not null, primary key
#  uid         :string           not null
#  ap_type     :string           not null
#  actor_id    :integer          not null
#  object_id   :integer
#  object_type :string
#  summary     :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_activities_on_uid  (uid)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#
