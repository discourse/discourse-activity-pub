# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActivity do
  let!(:category) { Fabricate(:category) }
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow, object: actor) }

  describe "#create" do
    context "with an invalid object type" do
      it "raises an error" do
        expect{
          described_class.create!(
            actor: actor,
            local: true,
            ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
            object_id: actor.model.id,
            object_type: actor.model.class.name
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with an invalid activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            actor: actor,
            local: true,
            ap_type: 'Maybe',
            object_id: follow_activity.id,
            object_type: follow_activity.class.name
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an activity" do
        accept = described_class.create!(
          actor: actor,
          local: true,
          ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
          object_id: follow_activity.id,
          object_type: follow_activity.class.name
        )
        expect(accept.errors.any?).to eq(false)
        expect(accept.persisted?).to eq(true)
      end
    end
  end

  describe '#audience' do
    let!(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post)}
    let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, object: note) }
    let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor) }

    before do
      toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
    end

    it "returns the group actor id" do
      expect(activity.audience).to eq(actor.ap_id)
    end
  end

  describe "#after_scheduled" do
    let!(:activity) { Fabricate(:discourse_activity_pub_activity_update, actor: actor) }

    before do
      freeze_time
    end

    it "calls activity_pub_after_scheduled with correct arguments" do
      Post.any_instance.expects(:activity_pub_after_scheduled).with({
        scheduled_at: Time.now.utc.iso8601
      }).once
      activity.after_scheduled(Time.now.utc.iso8601)
    end

    context "with create activity" do
      let(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }

      it "calls activity_pub_after_scheduled with correct arguments" do
        Post.any_instance.expects(:activity_pub_after_scheduled).with({
          scheduled_at: Time.now.utc.iso8601,
          published_at: nil,
          deleted_at: nil,
          updated_at: nil
        }).once
        activity.after_scheduled(Time.now.utc.iso8601)
      end
    end

    context "when delivering a collection" do
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, collection_id: collection.id) }
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note) }

      it "calls activity_pub_after_scheduled with correct arguments" do
        Post.any_instance.expects(:activity_pub_after_scheduled).with({
          scheduled_at: Time.now.utc.iso8601,
          published_at: nil,
          deleted_at: nil,
          updated_at: nil
        }).once
        collection.after_scheduled(Time.now.utc.iso8601)
      end
    end
  end

  describe "#before_deliver" do
    before do
      freeze_time
    end

    it "records published_at if not set" do
      original_time = Time.now.utc.iso8601

      follow_activity.before_deliver
      expect(follow_activity.reload.published_at).to eq(original_time) # rubocop:disable Discourse/TimeEqMatcher stored as a string

      unfreeze_time
      freeze_time(2.minutes.from_now) do
        follow_activity.before_deliver
        expect(follow_activity.reload.published_at).to eq(original_time) # rubocop:disable Discourse/TimeEqMatcher stored as a string
      end
    end

    context "with create activity" do
      let(:create_activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post.any_instance.expects(:activity_pub_after_publish).with({ published_at: Time.now.utc.iso8601 }).once
        create_activity.before_deliver
      end
    end

    context "with delete activity" do
      let(:delete_activity) { Fabricate(:discourse_activity_pub_activity_delete, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post.any_instance.expects(:activity_pub_after_publish).with({ deleted_at: Time.now.utc.iso8601 }).once
        delete_activity.before_deliver
      end
    end

    context "with update activity" do
      let(:update_activity) { Fabricate(:discourse_activity_pub_activity_update, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        Post.any_instance.expects(:activity_pub_after_publish).with({ updated_at: Time.now.utc.iso8601 }).once
        update_activity.before_deliver
      end
    end

    context "with accept activity" do
      let(:accept_activity) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor) }

      it "works" do
        accept_activity.before_deliver
        expect(accept_activity.published_at.to_i).to eq_time(Time.now.utc.to_i)
      end
    end

    context "when announcing a collection" do
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, collection_id: collection.id) }
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:create) { Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note) }
      let!(:activity) { Fabricate(:discourse_activity_pub_activity_announce, actor: actor, object: create) }

      it "calls activity_pub_after_publish with correct arguments" do
        Post.any_instance.expects(:activity_pub_after_publish).with({ published_at: Time.now.utc.iso8601 }).once
        activity.before_deliver
      end
    end
  end

  describe "#after_deliver" do
    before do
      freeze_time
    end

    context "with a follow activity" do
      let(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow, actor: actor) }

      context "when local" do
        before do
          follow_activity.update(local: true)
        end

        context "when not delivered" do
          it "destroys the activity" do
            follow_activity.after_deliver(false)
            expect(follow_activity).to be_destroyed
          end
        end

        context "when delievered" do
          it "does not destroy the activity" do
            follow_activity.after_deliver(true)
            expect(follow_activity).not_to be_destroyed
          end
        end
      end

      context "when remote" do
        before do
          follow_activity.update(local: false)
        end

        context "when not delivered" do
          it "does not destroy the activity" do
            follow_activity.after_deliver(false)
            expect(follow_activity).not_to be_destroyed
          end
        end

        context "when delievered" do
          it "does not destroy the activity" do
            follow_activity.after_deliver(false)
            expect(follow_activity).not_to be_destroyed
          end
        end
      end
    end

    context "with a local undo follow activity" do
      let!(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow, actor: actor) }
      let!(:undo_activity) { Fabricate(:discourse_activity_pub_activity_undo, actor: actor, object: follow_activity, local: true) }
      let!(:follow) { Fabricate(:discourse_activity_pub_follow, follower: actor, followed: follow_activity.object)}

      context "when not delivered" do
        it "does not destroy the follow" do
          undo_activity.after_deliver(false)
          expect(follow_activity).not_to be_destroyed
        end
      end

      context "when delievered" do
        it "destroys the follow" do
          undo_activity.after_deliver(true)
          expect(follow_activity).not_to be_destroyed
        end
      end
    end
  end
end