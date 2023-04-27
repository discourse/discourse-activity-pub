# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::NoteSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content

  def content
    content = object.content

    if SiteSetting.activity_pub_note_link_to_forum && object.stored.local?
      link_text = I18n.t("discourse_activity_pub.object.note.link_to_forum")
      link_html = "<a href=\"#{object.stored.model.full_url}\">#{link_text}</a>"
      content += "<br><br>#{link_html}"
    end

    content
  end

  def include_content?
    object.content.present? && object.stored.model && !object.stored.model.trashed?
  end
end