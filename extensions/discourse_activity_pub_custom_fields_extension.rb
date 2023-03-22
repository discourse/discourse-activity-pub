module DiscourseActivityPubCustomFieldsExtension
  def on_custom_fields_change
    super

    if @custom_fields_orig["activity_pub_enabled"] != @custom_fields["activity_pub_enabled"]
      self.activity_pub_publish_state
    end
  end
end