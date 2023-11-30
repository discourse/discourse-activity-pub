# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActivity do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow, object: actor) }

  describe "#create" do
    context "with an invalid object type" do
      it "raises an error" do
        expect {
          described_class.create!(
            actor: actor,
            local: true,
            ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
            object_id: actor.model.id,
            object_type: actor.model.class.name,
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with an invalid activity pub type" do
      it "raises an error" do
        expect {
          described_class.create!(
            actor: actor,
            local: true,
            ap_type: "Maybe",
            object_id: follow_activity.id,
            object_type: follow_activity.class.name,
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an activity" do
        accept =
          described_class.create!(
            actor: actor,
            local: true,
            ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
            object_id: follow_activity.id,
            object_type: follow_activity.class.name,
          )
        expect(accept.errors.any?).to eq(false)
        expect(accept.persisted?).to eq(true)
      end
    end
  end

  describe "#to" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
    let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }
    let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow1) do
      Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor)
    end

    context "when activity is private" do
      before { activity.update(visibility: DiscourseActivityPubActivity.visibilities[:private]) }

      it "addresses activity to followers only" do
        expect(activity.ap.json[:to]).to eq(actor.followers_collection.ap_id)
      end
    end

    context "when activity is public" do
      before { activity.update(visibility: DiscourseActivityPubActivity.visibilities[:public]) }

      it "addresses activity to public" do
        expect(activity.ap.json[:to]).to eq(DiscourseActivityPub::JsonLd.public_collection_id)
      end

      it "addresses object to public" do
        expect(activity.ap.json[:object][:to]).to eq(
          DiscourseActivityPub::JsonLd.public_collection_id,
        )
      end
    end
  end

  describe "#after_scheduled" do
    let!(:activity) { Fabricate(:discourse_activity_pub_activity_update, actor: actor) }

    before { freeze_time }

    it "calls activity_pub_after_scheduled with correct arguments" do
      Post
        .any_instance
        .expects(:activity_pub_after_scheduled)
        .with({ scheduled_at: Time.now.utc.iso8601 })
        .once
      activity.after_scheduled(Time.now.utc.iso8601)
    end

    context "with create activity" do
      let(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }

      it "calls activity_pub_after_scheduled with correct arguments" do
        Post
          .any_instance
          .expects(:activity_pub_after_scheduled)
          .with(
            {
              scheduled_at: Time.now.utc.iso8601,
              published_at: nil,
              deleted_at: nil,
              updated_at: nil,
            },
          )
          .once
        activity.after_scheduled(Time.now.utc.iso8601)
      end
    end

    context "when delivering a collection" do
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, collection_id: collection.id) }
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:activity) do
        Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note)
      end

      it "calls activity_pub_after_scheduled with correct arguments" do
        Post
          .any_instance
          .expects(:activity_pub_after_scheduled)
          .with(
            {
              scheduled_at: Time.now.utc.iso8601,
              published_at: nil,
              deleted_at: nil,
              updated_at: nil,
            },
          )
          .once
        collection.after_scheduled(Time.now.utc.iso8601)
      end
    end
  end

  describe "#after_deliver" do
    before { freeze_time }

    it "records published_at if not set" do
      original_time = Time.now.utc.iso8601

      follow_activity.after_deliver
      expect(follow_activity.reload.published_at).to eq(original_time) # rubocop:disable Discourse/TimeEqMatcher stored as a string

      unfreeze_time
      freeze_time(2.minutes.from_now) do
        follow_activity.after_deliver
        expect(follow_activity.reload.published_at).to eq(original_time) # rubocop:disable Discourse/TimeEqMatcher stored as a string
      end
    end

    context "with create activity" do
      let(:create_activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post
          .any_instance
          .expects(:activity_pub_after_publish)
          .with({ published_at: Time.now.utc.iso8601 })
          .once
        create_activity.after_deliver
      end
    end

    context "with delete activity" do
      let(:delete_activity) { Fabricate(:discourse_activity_pub_activity_delete, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post
          .any_instance
          .expects(:activity_pub_after_publish)
          .with({ deleted_at: Time.now.utc.iso8601 })
          .once
        delete_activity.after_deliver
      end
    end

    context "with update activity" do
      let(:update_activity) { Fabricate(:discourse_activity_pub_activity_update, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post
          .any_instance
          .expects(:activity_pub_after_publish)
          .with({ updated_at: Time.now.utc.iso8601 })
          .once
        update_activity.after_deliver
      end
    end

    context "with accept activity" do
      let(:accept_activity) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor) }

      it "works" do
        accept_activity.after_deliver
        expect(accept_activity.published_at.to_i).to eq_time(Time.now.utc.to_i)
      end
    end

    context "when announcing a collection" do
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, collection_id: collection.id) }
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:create) do
        Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note)
      end
      let!(:activity) do
        Fabricate(:discourse_activity_pub_activity_announce, actor: actor, object: create)
      end

      it "calls activity_pub_after_publish with correct arguments" do
        Post
          .any_instance
          .expects(:activity_pub_after_publish)
          .with({ published_at: Time.now.utc.iso8601 })
          .once
        activity.after_deliver
      end
    end
  end
end
