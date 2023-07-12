# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true
  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"

  def url
    local? && model&.activity_pub_url
  end

  def ready?(ap_type)
    return true unless local?

    case ap_type
    when DiscourseActivityPub::AP::Activity::Create.type, DiscourseActivityPub::AP::Activity::Update.type
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
