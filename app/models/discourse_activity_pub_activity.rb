# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::ActivityValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  after_create :deliver_composition, if: Proc.new { ap&.composition? }

  def active?
    case object_type
    when "DiscourseActivityPubActivity"
      object.active?
    when "DiscourseActivityPubObject"
      object.consistent?(ap_type)
    when "DiscourseActivityPubActor"
      object.ready?
    end
  end

  def deliver_composition
    return unless ap&.composition?

    actor.followers.each do |follower|
      deliver(to_actor_id: follower.id, delay: SiteSetting.activity_pub_delivery_delay_minutes.to_i)
    end
  end

  def deliver(to_actor_id: nil, delay: nil)
    return unless to_actor_id

    args = {
      activity_id: self.id,
      from_actor_id: actor.id,
      to_actor_id: to_actor_id
    }

    if delay
      Jobs.enqueue_in(delay.minutes, :discourse_activity_pub_deliver, args)
    else
      Jobs.enqueue(:discourse_activity_pub_deliver, args)
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_activities
#
#  id          :bigint           not null, primary key
#  ap_id       :string           not null
#  ap_key      :string
#  ap_type     :string           not null
#  local       :boolean
#  actor_id    :integer          not null
#  object_id   :string
#  object_type :string
#  summary     :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_activities_on_ap_id  (ap_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#
