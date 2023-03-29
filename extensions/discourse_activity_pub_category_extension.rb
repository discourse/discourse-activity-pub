# frozen_string_literal: true
module DiscourseActivityPubCategoryExtension
  def custom_field_changed(field_name)
    @custom_fields_orig[field_name] != @custom_fields[field_name]
  end

  # TODO (future): add serverside plugin api for on_custom_fields_change
  def on_custom_fields_change
    super
    return unless SiteSetting.activity_pub_enabled

    if custom_field_changed("activity_pub_enabled") && !@custom_fields_orig['activity_pub_username'] && !@custom_fields['activity_pub_username']
      self.errors.add(:activity_pub_enabled, I18n.t("category.discourse_activity_pub.error.enable_without_username"))
    end

    if custom_field_changed("activity_pub_username")
      if @custom_fields_orig['activity_pub_username'].present? && self.activity_pub_actor.present?
        self.errors.add(:activity_pub_enabled, I18n.t("category.discourse_activity_pub.error.no_change_when_set"))
      else
        DiscourseActivityPub::UsernameValidator.perform_validation(self, 'activity_pub_username')
      end
    end

    raise ActiveRecord::Rollback if self.errors.any?

    if custom_field_changed("activity_pub_enabled")
      self.activity_pub_publish_state
    end
  end
end