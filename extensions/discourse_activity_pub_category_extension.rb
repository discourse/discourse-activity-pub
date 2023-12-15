# frozen_string_literal: true
module DiscourseActivityPubCategoryExtension
  def custom_field_changed(field_name)
    @custom_fields_orig[field_name] != @custom_fields[field_name]
  end

  # TODO (future): PR discourse/discourse to add plugin api for on_custom_fields_change
  def on_custom_fields_change
    super
    return unless SiteSetting.activity_pub_enabled

    if custom_field_changed("activity_pub_enabled") &&
         !@custom_fields_orig["activity_pub_username"] && !@custom_fields["activity_pub_username"]
      self.errors.add(
        :activity_pub_enabled,
        I18n.t("category.discourse_activity_pub.error.enable_without_username"),
      )
    end

    if custom_field_changed("activity_pub_username")
      if @custom_fields_orig["activity_pub_username"].present? && self.activity_pub_actor.present?
        self.errors.add(
          :activity_pub_enabled,
          I18n.t("category.discourse_activity_pub.error.no_change_when_set"),
        )
      else
        DiscourseActivityPub::UsernameValidator.perform_validation(self, "activity_pub_username")

        if self.errors.blank? &&
             DiscourseActivityPubActor.username_unique?(
               @custom_fields["activity_pub_username"],
               model_id: self.id,
             )
          self.errors.add(
            :activity_pub_username,
            I18n.t("category.discourse_activity_pub.error.username_taken"),
          )
        end
      end
    end

    if @custom_fields["activity_pub_publication_type"] == "full_topic" &&
         @custom_fields["activity_pub_default_visibility"] == "private"
      self.errors.add(
        :activity_pub_default_visibility,
        I18n.t("category.discourse_activity_pub.error.full_topic_must_be_public"),
      )
    end

    raise ActiveRecord::Rollback if self.errors.any?

    self.activity_pub_publish_state if custom_field_changed("activity_pub_enabled")
  end
end
