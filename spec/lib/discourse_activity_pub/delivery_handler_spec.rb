# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::DeliveryHandler do
  let!(:delivery_actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: delivery_actor) }
  let!(:follower) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:follow) { Fabricate(:discourse_activity_pub_follow, follower: follower, followed: delivery_actor) }

  def expect_job(enqueued: true, activity_id: nil, delay: nil)
    args = {
      args: {
        activity_id: activity_id || activity.id,
        from_actor_id: delivery_actor.id,
        to_actor_id: follower.id
      },
      at: (delay || SiteSetting.activity_pub_delivery_delay_minutes).to_i.minutes.from_now
    }
    expect(job_enqueued?(job: :discourse_activity_pub_deliver, **args)).to eq(enqueued)
  end

  def expect_log(message)
    prefix = "#{delivery_actor.ap_id} failed to schedule #{activity.ap_id} for delivery"
    expect(@fake_logger.warnings.last).to eq(
      "[Discourse Activity Pub] #{prefix}: #{message}"
    )
  end

  def perform_delivery(delay: SiteSetting.activity_pub_delivery_delay_minutes)
    described_class.perform(delivery_actor, activity, delay)
  end

  before do
    SiteSetting.activity_pub_verbose_logging = true
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
    freeze_time
  end

  after do
    SiteSetting.activity_pub_verbose_logging = false
    Rails.logger = @orig_logger
  end

  describe "#perform" do
    context "when delivery actor is not ready" do
      it "returns false" do
        expect(perform_delivery).to eq(false)
      end

      it "does not enqueue any delivery jobs" do
        perform_delivery
        expect_job(enqueued: false)
      end

      it "logs the right warning" do
        perform_delivery
        expect_log("delivery actor not ready")
      end
    end

    context "when delivery actor is ready" do
      before do
        toggle_activity_pub(delivery_actor.model, callbacks: true)
      end

      context "when activity is not ready" do
        before do
          activity.object.model.trash!
        end

        it "returns false" do
          expect(perform_delivery).to eq(false)
        end

        it "does not enqueue any delivery jobs" do
          expect_job(enqueued: false)
        end

        it "logs the right warning" do
          perform_delivery
          expect_log("activity not ready")
        end
      end

      context "when activity is ready" do

        context "when delivery actor has no followers" do
          before do
            follow.destroy!
          end

          it "returns nil" do
            expect(perform_delivery).to eq(nil)
          end

          it "does not enqueue any delivery jobs" do
            expect_job(enqueued: false)
          end
        end

        context "when delivery actor has followers" do
          it "enqueues delivery to the delivery actor's followers" do
            perform_delivery
            expect_job
          end

          it "returns the activity enqueued for delivery" do
            expect(perform_delivery).to eq(activity)
          end

          it "cancels existing scheduled deliveries" do
            job_args = {
              activity_id: activity.id,
              from_actor_id: delivery_actor.id,
              to_actor_id: follower.id
            }
            Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, job_args).once
            perform_delivery
          end

          context "when given a delay" do
            it "enqueues delivery with the right delay" do
              perform_delivery(delay: 10)
              expect_job(delay: 10)
            end
          end

          context "when delivery actor and activity actor are different" do
            let!(:activity_actor) { Fabricate(:discourse_activity_pub_actor_person) }

            before do
              activity.actor_id = activity_actor.id
              activity.save!
            end

            it "wraps activity in announce" do
              result = perform_delivery
              announce = DiscourseActivityPubActivity.find_by(
                local: true,
                actor_id: delivery_actor.id,
                object_id: activity.id,
                object_type: activity.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
                visibility: 0
              )
              expect(result).to eq(announce)
              expect_job(activity_id: announce.id)
            end
          end
        end
      end
    end
  end
end