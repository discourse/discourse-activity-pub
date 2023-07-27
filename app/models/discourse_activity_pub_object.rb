# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true
  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"

  belongs_to :parent, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'in_reply_to'
  has_many :replies, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'in_reply_to'

  attr_accessor :to

  def url
    if local?
      model&.activity_pub_full_url
    else
      self.read_attribute(:url)
    end
  end

  def ready?(ap_type = nil)
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

  def in_reply_to_post
    parent&.model_type == 'Post' && parent.model
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_objects
#
#  id           :bigint           not null, primary key
#  ap_id        :string           not null
#  ap_key       :string
#  ap_type      :string           not null
#  local        :boolean
#  model_id     :integer
#  model_type   :string
#  content      :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  in_reply_to  :string
#  published_at :datetime
#  url          :string
#
# Indexes
#
#  index_discourse_activity_pub_objects_on_ap_id  (ap_id)
#
