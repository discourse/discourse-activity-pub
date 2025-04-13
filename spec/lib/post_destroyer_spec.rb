# frozen_string_literal: true

RSpec.describe PostDestroyer do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post1) { Fabricate(:post, user: user, topic: topic, post_number: 1) }
  let!(:post2) { Fabricate(:post, user: user, topic: topic, post_number: 2) }
  let!(:post3) { Fabricate(:post, user: user, topic: topic, post_number: 3) }
  let!(:post4) { Fabricate(:post, user: user) }
  let!(:note1) { Fabricate(:discourse_activity_pub_object_note, model: post1) }
  let!(:note2) { Fabricate(:discourse_activity_pub_object_note, model: post2) }
  let!(:note3) { Fabricate(:discourse_activity_pub_object_note, model: post3, local: false) }
  let!(:activity) do
    Fabricate(:discourse_activity_pub_activity_create, object: note1, published_at: Time.now)
  end

  before { toggle_activity_pub(category) }

  def perform_destroy(post)
    PostDestroyer.new(user, post).destroy
  end

  def perform_recover(post)
    PostDestroyer.new(user, post).recover
  end

  describe "destroy" do
    context "with an activity pub post" do
      context "with a local note" do
        it "calls the delete callback" do
          post1.expects(:perform_activity_pub_activity).with(:delete).once
          perform_destroy(post1)
        end
      end

      describe "with a remote note" do
        before do
          note1.local = false
          note1.save!
        end

        it "does not call the delete callback" do
          post1.expects(:perform_activity_pub_activity).with(:delete).never
          perform_destroy(post1)
        end
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        post4.expects(:perform_activity_pub_activity).never
        perform_destroy(post4)
      end
    end
  end

  describe "recover" do
    context "when published" do
      before do
        topic.create_activity_pub_collection!
        post1.custom_fields["activity_pub_published_at"] = Time.now
        post2.custom_fields["activity_pub_published_at"] = Time.now
        post3.custom_fields["activity_pub_published_at"] = Time.now
        post1.save_custom_fields(true)
        post2.save_custom_fields(true)
        post3.save_custom_fields(true)
      end

      context "with a trashed first post" do
        context "with a local note" do
          it "restores the tombstoned post note" do
            perform_destroy(post1)
            expect(note1.reload.ap_type).to eq("Tombstone")
            perform_recover(post1)
            expect(note1.reload.ap_type).to eq("Note")
          end

          it "restores the tombstoned topic collection" do
            perform_destroy(post1)
            expect(topic.activity_pub_object.reload.ap_type).to eq("Tombstone")
            perform_recover(post1)
            expect(topic.activity_pub_object.reload.ap_type).to eq("OrderedCollection")
          end

          it "creates a create activity with the note" do
            perform_recover(post1)
            expect(
              post1
                .activity_pub_actor
                .activities
                .where.not(id: activity.id)
                .where(
                  object_id: note1.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Create",
                )
                .exists?,
            ).to eq(true)
          end
        end

        describe "with a remote note" do
          it "does not call the create callback" do
            post3.expects(:perform_activity_pub_activity).with(:create).never
            perform_recover(post3)
          end
        end
      end

      context "with a trashed reply" do
        before { PostDestroyer.new(Fabricate(:admin), post2, force_destroy: false).destroy }

        it "restores the tombstoned reply note" do
          perform_destroy(post2)
          expect(note2.reload.ap_type).to eq("Tombstone")
          perform_recover(post2)
          expect(note2.reload.ap_type).to eq("Note")
        end

        it "creates a create activity with the note" do
          perform_recover(post2)
          expect(
            post2
              .activity_pub_actor
              .activities
              .where(
                object_id: note2.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Create",
              )
              .exists?,
          ).to eq(true)
        end
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        post4.expects(:perform_activity_pub_activity).never
        perform_recover(post4)
      end
    end
  end
end
