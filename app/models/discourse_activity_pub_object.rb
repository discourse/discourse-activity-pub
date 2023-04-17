# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, polymorphic: true, optional: true
  has_one :activity, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"

  def ready?
    return true unless local?

    case activity.ap_type
    when DiscourseActivityPub::AP::Activity::Create.type
      !!model && !model.trashed?
    when DiscourseActivityPub::AP::Activity::Delete.type
      !model || model.trashed?
    else
      false
    end
  end

  def update_from_model
    return unless model && !model.trashed?
    self.content = model.activity_pub_content
    self.save!
  end

  def self.handle_model_callback(model, ap_type_sym)
    ap = DiscourseActivityPub::AP::Object.from_type(ap_type_sym)
    return unless model.activity_pub_enabled && ap&.composition?

    # We don't currently permit updates after publication
    return if model.activity_pub_published? && ap_type_sym == :update

    # If we're pre-publication destroy all associated objects and activities on delete.
    if !model.activity_pub_published? && ap_type_sym == :delete
      objects = DiscourseActivityPubObject.where(model_id: model.id, model_type: model.class.name)
      objects.each { |object| object.activity.destroy! }
      objects.destroy_all
      return
    end

    ActiveRecord::Base.transaction do
      if !model.activity_pub_published? && ap_type_sym == :update
        object = model.activity_pub_objects.find_by(ap_type: DiscourseActivityPub::AP::Object::Note.type)
      else
        object = model.activity_pub_objects.build(local: true)
      end

      # We intentionally create a contentless object on delete for coherence.
      if %i(create update).include?(ap_type_sym)
        object.content = model.activity_pub_content
      end

      object.save!

      if ap_type_sym != :update
        DiscourseActivityPubActivity.create!(
          local: true,
          actor_id: model.activity_pub_actor.id,
          object_id: object.id,
          object_type: 'DiscourseActivityPubObject',
          ap_type: ap.type
        )
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_objects
#
#  id         :bigint           not null, primary key
#  ap_id      :string           not null
#  ap_key     :string
#  ap_type    :string           not null
#  local      :boolean
#  model_id   :integer
#  model_type :string
#  content    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_objects_on_ap_id  (ap_id)
#
