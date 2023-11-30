# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::DeliveryHandler do
  let!(:category) { Fabricate(:category) }
  let!(:delivery_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: delivery_actor) }
  let!(:follower) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:follow) do
    Fabricate(:discourse_activity_pub_follow, follower: follower, followed: delivery_actor)
  end

  def expect_job(enqueued: true, object_id: nil, object_type: nil, delay: nil)
    args = {
      args: {
        object_id: object_id || activity.id,
        object_type: object_type || "DiscourseActivityPubActivity",
        from_actor_id: delivery_actor.id,
        to_actor_id: follower.id,
      },
      at: (delay || SiteSetting.activity_pub_delivery_delay_minutes).to_i.minutes.from_now,
    }
    expect(job_enqueued?(job: :discourse_activity_pub_deliver, **args)).to eq(enqueued)
  end

  def expect_log(message)
    prefix = "#{delivery_actor.ap_id} failed to schedule #{activity.ap_id} for delivery"
    expect(@fake_logger.warnings.last).to eq("[Discourse Activity Pub] #{prefix}: #{message}")
  end

  def perform_delivery(object: activity, delay: SiteSetting.activity_pub_delivery_delay_minutes)
    described_class.perform(
      actor: delivery_actor,
      object: object,
      recipients: delivery_actor.followers,
      delay: delay,
    )
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
      before { toggle_activity_pub(delivery_actor.model, callbacks: true) }

      context "when activity is not ready" do
        before { activity.object.model.trash! }

        it "returns false" do
          expect(perform_delivery).to eq(false)
        end

        it "does not enqueue any delivery jobs" do
          expect_job(enqueued: false)
        end

        it "logs the right warning" do
          perform_delivery
          expect_log("object not ready")
        end
      end

      context "when activity is ready" do
        context "when delivery actor has no followers" do
          before { follow.destroy! }

          it "returns false" do
            expect(perform_delivery).to eq(false)
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
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: delivery_actor.id,
              to_actor_id: follower.id,
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

          context "when activities are in a collection" do
            let!(:topic) { Fabricate(:topic, category: category) }
            let!(:user) { Fabricate(:user) }
            let!(:post1) { Fabricate(:post, user: user, topic: topic) }
            let!(:post2) { Fabricate(:post, user: user, topic: topic) }
            let!(:person) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
            let!(:collection) do
              Fabricate(:discourse_activity_pub_ordered_collection, model: topic)
            end
            let!(:note1) do
              Fabricate(
                :discourse_activity_pub_object_note,
                model: post1,
                collection_id: collection.id,
              )
            end
            let!(:note2) do
              Fabricate(
                :discourse_activity_pub_object_note,
                model: post2,
                collection_id: collection.id,
              )
            end
            let!(:activity1) do
              Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note1)
            end
            let!(:activity2) do
              Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note2)
            end

            it "delivers the collection" do
              perform_delivery(object: collection)
              expect_job(object_id: collection.id, object_type: "DiscourseActivityPubCollection")
            end
          end
        end
      end
    end
  end
end
