# frozen_string_literal: true

RSpec.describe PostRevisor do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post) { Fabricate(:post, user: user, topic: topic) }

  describe "revise" do
    subject { PostRevisor.new(post) }

    before do
      toggle_activity_pub(category, callbacks: true)
    end

    context "when revising a published activity pub post" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
      let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, object: note, published_at: Time.now) }

      describe "with the same note content" do
        it "allows the revision" do
          updated_raw = "[note]#{post.raw}[/note] revision outside note"
          expect { subject.revise!(user, raw: updated_raw) }.not_to raise_error
          post.reload
          expect(post.raw).to eq(updated_raw)
          expect(post.activity_pub_content).to eq(note.content)
        end
      end

      describe "with different note content" do
        it "adds the right error" do
          subject.revise!(user, raw: "#{post.raw} revision inside note")
          expect(post.errors.present?).to eq(true)
          expect(post.errors.messages[:base].first).to eq(
            I18n.t("post.discourse_activity_pub.error.edit_after_publication")
          )
        end
      end
    end
  end
end