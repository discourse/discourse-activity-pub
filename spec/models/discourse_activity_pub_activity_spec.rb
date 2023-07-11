# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActivity do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
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

  describe "#deliver_composition" do
    before do
      toggle_activity_pub(actor.model)
    end

    context "when not creating composition activity" do
      it "does not run" do
        described_class.any_instance.expects(:deliver_composition).never
        described_class.create!(
          actor: actor,
          local: true,
          ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
          object_id: follow_activity.id,
          object_type: follow_activity.class.name
        )
      end
    end

    context "when creating composition activity" do
      let(:create_activity) { Fabricate(:discourse_activity_pub_activity_create, actor: actor) }
      let(:delete_activity) { Fabricate(:discourse_activity_pub_activity_delete, actor: actor) }

      context "when actor has followers" do
        let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
        let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor) }
        let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
        let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: actor) }

        it "enqueues deliveries to actor's followers with appropriate delay" do
          freeze_time

          activity = create_activity
          delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
          job1_args = {
            activity_id: activity.id,
            from_actor_id: actor.id,
            to_actor_id: follower1.id
          }
          job2_args = {
            activity_id: activity.id,
            from_actor_id: actor.id,
            to_actor_id: follower2.id
          }
          expect(
            job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args, at: delay.minutes.from_now)
          ).to eq(true)
          expect(
            job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args, at: delay.minutes.from_now)
          ).to eq(true)
        end

        it "enqueues delivery of delete activities instantly" do
          activity = delete_activity
          job1_args = {
            activity_id: activity.id,
            from_actor_id: actor.id,
            to_actor_id: follower1.id
          }
          job2_args = {
            activity_id: activity.id,
            from_actor_id: actor.id,
            to_actor_id: follower2.id
          }
          expect(
            job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args)
          ).to eq(true)
          expect(
            job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args)
          ).to eq(true)
        end
      end
    end
  end

  describe "#deliver" do
    let(:accept_activity) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor, object: follow_activity) }
    let(:job_args) {
      {
        activity_id: accept_activity.id,
        from_actor_id: accept_activity.actor.id,
        to_actor_id: accept_activity.object.actor.id
      }
    }

    context "when given a delay" do
      let(:delay) { 10 }

      it "enqueues delivery with delay" do
        freeze_time
        expect_enqueued_with(job: :discourse_activity_pub_deliver, args: job_args, at: delay.minutes.from_now) do
          accept_activity.deliver(to_actor_id: accept_activity.object.actor.id, delay: delay)
        end
      end
    end

    context "when not given a delay" do
      it "enqueues delivery without delay" do
        expect_enqueued_with(job: :discourse_activity_pub_deliver, args: job_args) do
          accept_activity.deliver(to_actor_id: accept_activity.object.actor.id)
        end
      end
    end

    it "cancels existing scheduled deliveries" do
      job_args = {
        activity_id: accept_activity.id,
        from_actor_id: accept_activity.actor.id,
        to_actor_id: accept_activity.object.actor.id
      }
      Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, job_args).once
      accept_activity.deliver(to_actor_id: accept_activity.object.actor.id)
    end
  end

  describe "#after_deliver" do
    it "records published_at if not set" do
      freeze_time
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
        freeze_time
        original_time = Time.now.utc.iso8601
        Post.any_instance.expects(:activity_pub_after_publish).with({ published_at: original_time }).once
        create_activity.after_deliver
      end
    end

    context "with delete activity" do
      let(:delete_activity) { Fabricate(:discourse_activity_pub_activity_delete, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        freeze_time
        original_time = Time.now.utc.iso8601
        Post.any_instance.expects(:activity_pub_after_publish).with({ deleted_at: original_time }).once
        delete_activity.after_deliver
      end
    end

    context "with update activity" do
      let(:update_activity) { Fabricate(:discourse_activity_pub_activity_update, actor: actor) }

      it "calls activity_pub_after_publish on associated object models" do
        freeze_time
        original_time = Time.now.utc.iso8601
        Post.any_instance.expects(:activity_pub_after_publish).with({ updated_at: original_time }).once
        update_activity.after_deliver
      end
    end

    context "with accept activity" do
      let(:accept_activity) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor) }

      it "works" do
        freeze_time
        accept_activity.after_deliver
        expect(accept_activity.published_at.to_i).to eq_time(Time.now.utc.to_i)
      end
    end
  end
end