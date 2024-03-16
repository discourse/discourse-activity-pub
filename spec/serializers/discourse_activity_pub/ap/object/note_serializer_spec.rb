# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Object::NoteSerializer do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Post content") }
  fab!(:post_actor) do
    Fabricate(:discourse_activity_pub_actor_person, model: post.user, local: true)
  end

  before { toggle_activity_pub(category, callbacks: true) }

  context "with link to forum enabled" do
    before { SiteSetting.activity_pub_note_link_to_forum = true }

    it "serializes note content with a link to the forum" do
      note = Fabricate(:discourse_activity_pub_object_note, model: post, local: true)
      link_text = I18n.t("discourse_activity_pub.object.note.link_to_forum")
      link_html = "<a href=\"#{note.model.activity_pub_url}\">#{link_text}</a>"
      expect(note.ap.json[:content]).to eq("#{note.content}<br><br>#{link_html}")
    end
  end

  context "with link to forum disabled" do
    before { SiteSetting.activity_pub_note_link_to_forum = false }

    it "serializes note content without a link to the forum" do
      note = Fabricate(:discourse_activity_pub_object_note, model: post, local: true)
      expect(note.ap.json[:content]).to eq(note.content)
    end
  end

  context "with first_post enabled" do
    it "serializes attributedTo as the category actor" do
      note = Fabricate(:discourse_activity_pub_object_note, model: post, local: true)
      expect(note.ap.json[:attributedTo]).to eq(category.activity_pub_actor.ap_id)
    end
  end

  context "with full_topic enabled" do
    before do
      toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
      post.topic.create_activity_pub_collection!
    end

    it "serializes attributedTo as the post object attributed_to actor" do
      note =
        Fabricate(
          :discourse_activity_pub_object_note,
          model: post,
          local: true,
          attributed_to: post_actor,
        )
      expect(note.ap.json[:attributedTo]).to eq(post_actor.ap_id)
    end
  end
end
