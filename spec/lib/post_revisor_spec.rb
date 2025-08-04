# frozen_string_literal: true

RSpec.describe PostRevisor do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let!(:post) { Fabricate(:post, user: user, topic: topic) }

  describe "revise" do
    subject(:post_revisor) { PostRevisor.new(post) }

    before { toggle_activity_pub(category) }

    context "when revising a published activity pub post" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: true) }
      let!(:activity) do
        Fabricate(:discourse_activity_pub_activity_create, object: note, published_at: Time.now)
      end
      let!(:post_actor) { Fabricate(:discourse_activity_pub_actor_person, model: user) }

      describe "with the same note content" do
        it "allows the revision" do
          updated_raw = "[note]#{post.raw}[/note] revision outside note"
          expect { post_revisor.revise!(user, raw: updated_raw) }.not_to raise_error
          post.reload
          expect(post.raw).to eq(updated_raw)
          expect(post.activity_pub_content).to eq(note.content)
        end
      end

      describe "with different note content" do
        it "does not add an error" do
          post_revisor.revise!(user, raw: "#{post.raw} revision inside note")
          expect(post.errors.present?).to eq(false)
        end

        it "performs the edit" do
          updated_raw = "#{post.raw} revision inside note"
          post_revisor.revise!(user, raw: updated_raw)
          expect(post.reload.raw).to eq(updated_raw)
          expect(post.activity_pub_content).to eq("<p>#{updated_raw}</p>")
        end
      end

      it "allows a category change" do
        category2 = Fabricate(:category)
        expect { post_revisor.revise!(user, category_id: category2.id) }.not_to raise_error
        post.topic.reload
        expect(post.topic.category_id).to eq(category2.id)
      end

      context "with full_topic enabled" do
        before do
          toggle_activity_pub(category, publication_type: "full_topic")
          topic.create_activity_pub_collection!
        end

        context "with a topic title change" do
          it "updates the topic collection name" do
            new_title = "New topic title"
            expect { post_revisor.revise!(user, title: new_title) }.not_to raise_error
            expect(post.topic.reload.title).to eq(new_title)
            expect(post.topic.activity_pub_object.reload.name).to eq(new_title)
          end
        end

        context "when the revisor is not the post user" do
          let!(:staff) { Fabricate(:moderator) }

          it "creates an activity with the revising user's actor" do
            post_revisor.revise!(staff, raw: "#{post.raw} revision")
            expect(
              staff
                .reload
                .activity_pub_actor
                .activities
                .where(
                  object_id: post.activity_pub_object.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Update",
                )
                .exists?,
            ).to eq(true)
          end

          it "does not create an activity with the post user's actor" do
            post_revisor.revise!(staff, raw: "#{post.raw} revision")
            expect(
              post_actor
                .activities
                .where(
                  object_id: post.activity_pub_object.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Update",
                )
                .exists?,
            ).to eq(false)
          end
        end

        context "when the post is a wiki" do
          before do
            post.wiki = true
            post.save!
          end

          context "when the revisor is not the post user" do
            let!(:another_user) { Fabricate(:user) }

            it "creates an activity with the revising user's actor" do
              post_revisor.revise!(another_user, raw: "#{post.raw} revision")
              expect(
                another_user
                  .reload
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  )
                  .exists?,
              ).to eq(true)
            end

            it "does not create an activity with the post user's actor" do
              post_revisor.revise!(another_user, raw: "#{post.raw} revision")
              expect(
                post_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  )
                  .exists?,
              ).to eq(false)
            end
          end
        end
      end
    end

    context "when revising a non-activity-pub post" do
      context "with full_topic enabled" do
        before { toggle_activity_pub(category, publication_type: "full_topic") }
        it "allows updating the topic title" do
          new_title = "New topic title"
          expect { post_revisor.revise!(user, title: new_title) }.not_to raise_error
        end
      end
    end
  end
end
