# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Object::NoteSerializer do
  let!(:note) { Fabricate(:discourse_activity_pub_object_note) }

  context "with link to forum enabled" do
    before do
      SiteSetting.activity_pub_note_link_to_forum = true
    end

    it "serializes note content with a link to the forum" do
      link_text = I18n.t("discourse_activity_pub.object.note.link_to_forum")
      link_html = "<a href=\"#{note.model.full_url}\">#{link_text}</a>"
      expect(note.ap.json[:content]).to eq("#{note.content}<br><br>#{link_html}")
    end
  end

  context "with link to forum disabled" do
    before do
      SiteSetting.activity_pub_note_link_to_forum = false
    end

    it "serializes note content without a link to the forum" do
      expect(note.ap.json[:content]).to eq(note.content)
    end
  end
end
