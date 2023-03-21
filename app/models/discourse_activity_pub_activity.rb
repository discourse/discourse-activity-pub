# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::Concerns::Activity

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  before_validation :ensure_uid
  validates :actor_id, presence: true

  after_create :deliver, if: Proc.new { ap&.composed? }

  def deliver
    ap.stored = self
    ap.deliver
  end

  private

  def supported_object_types
    %w(DiscourseActivityPubActivity DiscourseActivityPubActor DiscourseActivityPubObject)
  end

  def ensure_uid
    self.uid = DiscourseActivityPub::JsonLd.generate_activity_id(actor, ap_type) if !self.uid
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
