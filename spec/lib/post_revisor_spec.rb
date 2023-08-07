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
        it "does not add an error" do
          subject.revise!(user, raw: "#{post.raw} revision inside note")
          expect(post.errors.present?).to eq(false)
        end

        it "performs the edit" do
          updated_raw = "#{post.raw} revision inside note"
          subject.revise!(user, raw: updated_raw)
          expect(post.reload.raw).to eq(updated_raw)
          expect(post.activity_pub_content).to eq(updated_raw)
        end
      end

      it "allows a category change" do
        category2 = Fabricate(:category)
        expect { subject.revise!(user, category_id: category2.id) }.not_to raise_error
        post.topic.reload
        expect(post.topic.category_id).to eq(category2.id)
      end

      context "with full_topic enabled" do
        before do
          toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
          topic.create_activity_pub_collection!
        end

        context "with a topic title change" do
          it "updates the topic collection summary" do
            new_title = "New topic title"
            expect { subject.revise!(user, title: new_title) }.not_to raise_error
            expect(post.topic.reload.title).to eq(new_title)
            expect(post.topic.activity_pub_object.reload.summary).to eq(new_title)
          end
        end
      end
    end
  end
end