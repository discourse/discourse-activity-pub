# frozen_string_literal: true

RSpec.describe Jobs::DiscourseActivityPubDeliver do
  let(:activity) { Fabricate(:discourse_activity_pub_activity_accept) }

  def expect_no_request
    DiscourseActivityPub::Request.expects(:new).never
  end

  def expect_request(actor_id: nil, uri: nil, body: nil)
    if !body
      body = activity.ap.json
      body[:to] = activity.object.actor.ap.id
    end

    DiscourseActivityPub::Request
      .expects(:new)
      .with(
        actor_id: actor_id || activity.actor.id,
        uri: uri || activity.object.actor.inbox,
        body: body
      )
      .once
  end

  def expect_post(returns: true)
    DiscourseActivityPub::Request
      .any_instance
      .expects(:post_json_ld)
      .returns(returns)

    if returns
      DiscourseActivityPub::DeliveryFailureTracker
        .any_instance
        .expects(:track_success)
        .once
    else
      DiscourseActivityPub::DeliveryFailureTracker
        .any_instance
        .expects(:track_failure)
        .once
    end
  end

  def build_job_args(args = {})
    {
      activity_id: args.key?(:activity_id) ? args[:activity_id] : activity.id,
      from_actor_id: args.key?(:from_actor_id) ? args[:from_actor_id] : activity.actor.id,
      to_actor_id: args.key?(:to_actor_id) ? args[:to_actor_id] : activity.object.actor.id,
      retry_count: args.key?(:retry_count) ? args[:retry_count] : nil
    }
  end

  def execute_job(args = {})
    described_class.new.execute(build_job_args(args))
  end

  context "without activity pub enabled" do
    before do
      SiteSetting.activity_pub_enabled = false
    end

    it "does not perform a request" do
      expect_no_request
      execute_job
    end
  end

  context "with site activity pub enabled" do
    before do
      SiteSetting.activity_pub_enabled = true
    end

    context "with login required" do
      before do
        SiteSetting.login_required = true
      end

      it "does not perform a request" do
        expect_no_request
        execute_job
      end
    end
  end

  context "with model activity pub disabled" do
    before do
      toggle_activity_pub(activity.actor.model, disable: true)
    end

    it "does not perform a request" do
      expect_no_request
      execute_job
    end
  end

  context "with model activity pub enabled" do
    before do
      toggle_activity_pub(activity.actor.model, callbacks: true)
    end

    context "without required arguments" do
      it "does not perform a request" do
        expect_no_request
        execute_job(activity_id: nil)
        execute_job(from_actor_id: nil)
        execute_job(to_actor_id: nil)
      end
    end

    context "with invalid arguments" do
      it "does not perform a request" do
        expect_no_request
        execute_job(activity_id: activity.id + 20)
        execute_job(from_actor_id: activity.actor.id + 20)
        execute_job(to_actor_id: activity.object.actor.id + 20)
      end
    end

    it "initializes the right request" do
      expect_request
      execute_job
    end

    it "performs the right request" do
      expect_post
      execute_job
    end

    context "when request succeeds" do
      before do
        expect_post(returns: true)
      end

      it "does not retry" do
        expect_not_enqueued_with(job: :discourse_activity_pub_deliver) do
          execute_job
        end
      end
    end

    context "when request fails" do
      before do
        expect_post(returns: false)
      end

      it "enqueues retries" do
        freeze_time

        retry_count = described_class::MAX_RETRY_COUNT - 1
        delay = described_class::RETRY_BACKOFF * retry_count
        next_job_args = build_job_args(retry_count: retry_count + 1 )

        expect_enqueued_with(job: :discourse_activity_pub_deliver, args: next_job_args, at: delay.minutes.from_now) do
          execute_job(retry_count: retry_count)
        end
      end

      it "does not retry more than the maximum retry count" do
        expect_not_enqueued_with(job: :discourse_activity_pub_deliver) do
          execute_job(retry_count: described_class::MAX_RETRY_COUNT)
        end
      end
    end

    context "when delivering a note" do
      let(:activity) { Fabricate(:discourse_activity_pub_activity_create) }
      let(:person) { Fabricate(:discourse_activity_pub_actor_person) }

      it "performs the right request" do
        body = activity.ap.json
        body[:to] = person.ap.id

        expect_request(
          actor_id: activity.actor.id,
          uri: person.inbox,
          body: body
        )
        execute_job(
          activity_id: activity.id,
          from_actor_id: activity.actor.id,
          to_actor_id: person.id
        )
      end

      context "when associated post is trashed" do
        before do
          activity.object.model.trash!
        end

        it "does not perform a request" do
          expect_no_request
          execute_job(
            activity_id: activity.id,
            from_actor_id: activity.actor.id,
            to_actor_id: person.id
          )
        end
      end
    end
  end
end
