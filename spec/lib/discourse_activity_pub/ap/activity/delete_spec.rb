# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Delete do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity::Compose }

  describe "#process" do
    context "with a remote note" do
      let!(:object_json) { build_object_json }
      let!(:tombstone_json) { build_object_json(id: object_json[:id], type: "Tombstone") }
      let!(:activity_json) do
        build_activity_json(
          object: object_json,
          type: "Delete",
          to: [category.activity_pub_actor.ap_id],
        )
      end
      let!(:note) do
        Fabricate(
          :discourse_activity_pub_object_note,
          ap_id: object_json[:id],
          local: false,
          model: post,
        )
      end

      before do
        toggle_activity_pub(category, publication_type: "full_topic")
        topic.create_activity_pub_collection!
      end

      context "when object id returns a tombstone" do
        before { stub_object_request(object_json, body: tombstone_json.to_json, status: 410) }

        it "creates an activity" do
          perform_process(activity_json)
          expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
        end

        it "trashes the post" do
          perform_process(activity_json)
          expect(post.reload.trashed?).to be(true)
        end

        it "tombstones the object" do
          perform_process(activity_json)
          expect(note.reload.tombstoned?).to be(true)
        end
      end

      context "when object id returns a 404" do
        before { stub_object_request(object_json, status: 404) }

        it "creates an activity" do
          perform_process(activity_json)
          expect(DiscourseActivityPubActivity.unscoped.exists?(ap_id: activity_json[:id])).to be(
            true,
          )
        end

        it "deletes the post" do
          perform_process(activity_json)
          expect(Post.unscoped.exists?(id: post.id)).to be(false)
        end

        it "deletes the object" do
          perform_process(activity_json)
          expect(DiscourseActivityPubObject.unscoped.exists?(ap_id: object_json[:id])).to be(false)
        end
      end
    end

    context "with a remote actor" do
      let!(:user) { Fabricate(:user) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: false, model: user) }
      let!(:actor_json) { actor.ap.json }
      let!(:tombstone_json) { build_object_json(id: actor_json[:id], type: "Tombstone") }
      let!(:activity_json) do
        build_activity_json(
          actor: actor_json,
          object: actor_json,
          type: "Delete",
          to: [category.activity_pub_actor.ap_id],
        )
      end

      before { toggle_activity_pub(category) }

      context "when actor id returns a tombstone" do
        before do
          setup_logging
          stub_object_request(actor_json, body: tombstone_json.to_json, status: 410)
        end
        after { teardown_logging }

        it "creates an activity" do
          perform_process(activity_json)
          expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
        end

        it "tombstones the actor" do
          perform_process(activity_json)
          expect(actor.reload.ap_type).to eq("Tombstone")
          expect(actor.reload.ap_former_type).to eq("Person")
        end

        context "when the actor has posts" do
          let!(:topic1) { Fabricate(:topic, category: category) }
          let!(:collection1) do
            Fabricate(
              :discourse_activity_pub_ordered_collection,
              model: topic1,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:topic2) { Fabricate(:topic, category: category) }
          let!(:collection2) do
            Fabricate(:discourse_activity_pub_ordered_collection, model: topic2)
          end
          let!(:post1) { Fabricate(:post, topic: topic1, post_number: 1, user: user) }
          let!(:note1) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post1,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:post2) { Fabricate(:post, topic: topic1, post_number: 2, user: user) }
          let!(:note2) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post2,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:post3) { Fabricate(:post, topic: topic2, post_number: 1) }
          let!(:note3) { Fabricate(:discourse_activity_pub_object_note, model: post3) }
          let!(:post4) { Fabricate(:post, topic: topic2, post_number: 2, user: user) }
          let!(:note4) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post4,
              attributed_to: actor,
              local: false,
            )
          end

          it "trashes the actor's posts" do
            perform_process(activity_json)
            expect(post1.reload.trashed?).to be(true)
            expect(post2.reload.trashed?).to be(true)
            expect(post3.reload.trashed?).to be(false)
            expect(post4.reload.trashed?).to be(true)
            expect(topic1.reload.trashed?).to be(true)
            expect(topic2.reload.trashed?).to be(false)
          end

          it "tombstones the actors objects" do
            perform_process(activity_json)
            expect(note1.reload.tombstoned?).to be(true)
            expect(note2.reload.tombstoned?).to be(true)
            expect(note3.reload.tombstoned?).to be(false)
            expect(note4.reload.tombstoned?).to be(true)
            expect(collection1.reload.tombstoned?).to be(true)
            expect(collection2.reload.tombstoned?).to be(false)
          end
        end
      end

      context "when actor id returns a 404" do
        before { stub_object_request(actor_json, body: tombstone_json.to_json, status: 404) }

        context "when the user is not staged" do
          it "creates an activity" do
            perform_process(activity_json)
            expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
          end

          it "tombstones the actor" do
            perform_process(activity_json)
            expect(actor.reload.ap_type).to eq("Tombstone")
            expect(actor.reload.ap_former_type).to eq("Person")
          end
        end

        context "when the user is staged by the ap plugin" do
          before do
            actor.model.update!(staged: true)
            actor.model.custom_fields[:activity_pub_user] = true
            actor.model.save_custom_fields(true)
            UserEmail.where(user_id: actor.model.id).destroy_all
          end

          it "does not create an activity" do
            perform_process(activity_json)
            expect(DiscourseActivityPubActivity.unscoped.exists?(ap_id: activity_json[:id])).to be(
              false,
            )
          end

          it "deletes the actor" do
            perform_process(activity_json)
            expect(DiscourseActivityPubActor.unscoped.exists?(id: actor.id)).to eq(false)
          end
        end

        context "when the actor has posts" do
          let!(:user) { Fabricate(:user) }
          let!(:topic1) { Fabricate(:topic, category: category) }
          let!(:collection1) do
            Fabricate(
              :discourse_activity_pub_ordered_collection,
              model: topic1,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:topic2) { Fabricate(:topic, category: category) }
          let!(:collection2) do
            Fabricate(:discourse_activity_pub_ordered_collection, model: topic2)
          end
          let!(:post1) { Fabricate(:post, topic: topic1, post_number: 1, user: user) }
          let!(:note1) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post1,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:post2) { Fabricate(:post, topic: topic1, post_number: 2, user: user) }
          let!(:note2) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post2,
              attributed_to: actor,
              local: false,
            )
          end
          let!(:post3) { Fabricate(:post, topic: topic2, post_number: 1) }
          let!(:note3) { Fabricate(:discourse_activity_pub_object_note, model: post3) }
          let!(:post4) { Fabricate(:post, topic: topic2, post_number: 2, user: user) }
          let!(:note4) do
            Fabricate(:discourse_activity_pub_object_note, model: post4, attributed_to: actor)
          end

          before do
            actor.model = user
            actor.save!
          end

          it "deletes the posts" do
            perform_process(activity_json)
            expect(Post.unscoped.exists?(post1.id)).to be(false)
            expect(Post.unscoped.exists?(post2.id)).to be(false)
            expect(Post.unscoped.exists?(post3.id)).to be(true)
            expect(Post.unscoped.exists?(post4.id)).to be(false)
            expect(Topic.unscoped.exists?(topic1.id)).to be(false)
            expect(Topic.unscoped.exists?(topic2.id)).to be(true)
          end

          it "deletes the post objects" do
            perform_process(activity_json)
            expect(DiscourseActivityPubObject.unscoped.exists?(note1.id)).to be(false)
            expect(DiscourseActivityPubObject.unscoped.exists?(note2.id)).to be(false)
            expect(DiscourseActivityPubObject.unscoped.exists?(note3.id)).to be(true)
            expect(DiscourseActivityPubObject.unscoped.exists?(note4.id)).to be(false)
            expect(DiscourseActivityPubCollection.unscoped.exists?(collection1.id)).to be(false)
            expect(DiscourseActivityPubCollection.unscoped.exists?(collection2.id)).to be(true)
          end
        end
      end

      context "with a group" do
        let!(:actor) do
          Fabricate(
            :discourse_activity_pub_actor_group,
            name: "External Category",
            username: "external-cat",
            local: false,
            model: user,
          )

          it "works" do
            perform_process(activity_json)
            expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
            expect(actor.reload.ap_type).to eq("Tombstone")
            expect(actor.reload.ap_former_type).to eq("Group")
          end
        end
      end
    end

    context "with a local actor" do
      let!(:user) { Fabricate(:user) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: true, model: user) }
      let!(:activity_json) do
        build_activity_json(
          actor: actor.ap.json,
          object: actor.ap.json,
          type: "Delete",
          to: [category.activity_pub_actor.ap_id],
        )
      end

      before do
        setup_logging
        toggle_activity_pub(category)
      end
      after { teardown_logging }

      it "does not create an activity" do
        perform_process(activity_json)
        expect(DiscourseActivityPubActivity.unscoped.exists?(ap_id: activity_json[:id])).to be(
          false,
        )
      end

      it "does not tombstone the actor" do
        perform_process(activity_json)
        expect(actor.reload.ap_type).to eq("Person")
      end

      it "logs the right warning" do
        perform_process(activity_json)
        expect(@fake_logger.warnings.last).to match(
          I18n.t("discourse_activity_pub.process.warning.activity_host_must_match_object_host"),
        )
        expect(actor.reload.ap_type).to eq("Person")
      end
    end
  end
end
