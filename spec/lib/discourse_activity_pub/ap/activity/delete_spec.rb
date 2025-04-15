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

      it "trashes the post" do
        perform_process(activity_json)
        expect(post.reload.trashed?).to be(true)
      end

      it "tombstones the object" do
        perform_process(activity_json)
        expect(note.reload.tombstoned?).to be(true)
      end

      it "creates an activity" do
        perform_process(activity_json)
        expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
      end
    end

    context "with a remote actor" do
      let!(:activity_json) do
        build_activity_json(
          actor: actor.ap.json,
          object: actor.ap.json,
          type: "Delete",
          to: [category.activity_pub_actor.ap_id],
        )
      end

      before { toggle_activity_pub(category) }

      context "with a person" do
        let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: false) }

        it "creates an activity" do
          perform_process(activity_json)
          expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
        end

        it "tombstones the actor" do
          perform_process(activity_json)
          expect(actor.reload.ap_type).to eq("Tombstone")
          expect(actor.reload.ap_former_type).to eq("Person")
        end

        context "with a user and posts" do
          let!(:user) { Fabricate(:user) }
          let!(:topic1) { Fabricate(:topic) }
          let!(:collection1) do
            Fabricate(
              :discourse_activity_pub_ordered_collection,
              model: topic1,
              attributed_to: actor,
            )
          end
          let!(:topic2) { Fabricate(:topic) }
          let!(:collection2) do
            Fabricate(:discourse_activity_pub_ordered_collection, model: topic2)
          end
          let!(:post1) { Fabricate(:post, topic: topic1, post_number: 1, user: user) }
          let!(:note1) do
            Fabricate(:discourse_activity_pub_object_note, model: post1, attributed_to: actor)
          end
          let!(:post2) { Fabricate(:post, topic: topic1, post_number: 2, user: user) }
          let!(:note2) do
            Fabricate(:discourse_activity_pub_object_note, model: post2, attributed_to: actor)
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

          it "tombstones the actor's objects" do
            perform_process(activity_json)
            expect(note1.reload.tombstoned?).to be(true)
            expect(note2.reload.tombstoned?).to be(true)
            expect(note3.reload.tombstoned?).to be(false)
            expect(note4.reload.tombstoned?).to be(true)
            expect(collection1.reload.tombstoned?).to be(true)
            expect(collection2.reload.tombstoned?).to be(false)
          end

          it "trashes the user's posts" do
            perform_process(activity_json)
            expect(post1.reload.trashed?).to be(true)
            expect(post2.reload.trashed?).to be(true)
            expect(post3.reload.trashed?).to be(false)
            expect(post4.reload.trashed?).to be(true)
            expect(topic1.reload.trashed?).to be(true)
            expect(topic2.reload.trashed?).to be(false)
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
        expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(false)
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
