# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, polymorphic: true, optional: true
  has_one :activity, class_name: "DiscourseActivityPubActivity"

  def self.handle_model_callback(model, ap_type_sym)
    ap = DiscourseActivityPub::AP::Object.from_type(ap_type_sym)
    return unless model.activity_pub_enabled && ap&.composed?

    ActiveRecord::Base.transaction do
      object = model.activity_pub_objects.build
      object.content = model.activity_pub_content if %i(create update).include?(ap_type_sym)
      object.save!

      DiscourseActivityPubActivity.create!(
        actor_id: model.activity_pub_actor.id,
        object_id: object.id,
        object_type: 'DiscourseActivityPubObject',
        ap_type: ap.type
      )
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_objects
#
#  id         :bigint           not null, primary key
#  uid        :string           not null
#  ap_type    :string           not null
#  model_id   :integer
#  model_type :string
#  content    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_objects_on_uid  (uid)
#
