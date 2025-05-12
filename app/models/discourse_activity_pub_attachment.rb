# frozen_string_literal: true

class DiscourseActivityPubAttachment < ActiveRecord::Base
  include DiscourseActivityPub::AP::TypeValidations
  include DiscourseActivityPub::AP::ObjectValidations

  belongs_to :object, class_name: "DiscourseActivityPubObject", polymorphic: true

  validate :validate_media_type

  protected

  def validate_media_type
    unless MiniMime.lookup_by_content_type(self.media_type)
      self.errors.add(
        :media_type,
        I18n.t(
          "activerecord.errors.models.discourse_activity_pub_attachment.attributes.media_type.invalid",
        ),
      )
      raise ActiveRecord::RecordInvalid
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_attachments
#
#  id          :bigint           not null, primary key
#  ap_type     :string           not null
#  object_id   :bigint           not null
#  object_type :string           not null
#  url         :string
#  name        :string
#  media_type  :string(200)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
