# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::DeliveryHandler do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post) { Fabricate(:post, user: user, topic: topic) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
  let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:follow) { Fabricate(:discourse_activity_pub_follow, follower: person, followed: group) }

  def expect_job(enqueued: true, object_id: nil, object_type: nil, delay: nil)
    args = {
      args: {
        object_id: object_id || activity.id,
        object_type: object_type || 'DiscourseActivityPubActivity',
        from_actor_id: group.id,
        send_to: person.inbox
      },
      at: (delay || SiteSetting.activity_pub_delivery_delay_minutes).to_i.minutes.from_now
    }
    expect(job_enqueued?(job: :discourse_activity_pub_deliver, **args)).to eq(enqueued)
  end

  def expect_log(message)
    prefix = "#{group.ap_id} failed to schedule #{activity.ap_id} for delivery"
    expect(@fake_logger.warnings.last).to eq(
      "[Discourse Activity Pub] #{prefix}: #{message}"
    )
  end

  def perform_delivery(object: activity, delay: SiteSetting.activity_pub_delivery_delay_minutes)
    described_class.perform(
      actor: group,
      object: object,
      recipient_ids: group.followers.map(&:id),
      delay: delay
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
      before do
        toggle_activity_pub(category, callbacks: true)
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
          expect_log("object not ready")
        end
      end

      context "when activity is ready" do

        context "when delivery actor has no followers" do
          before do
            follow.destroy!
          end

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
              object_type: 'DiscourseActivityPubActivity',
              from_actor_id: group.id,
              send_to: person.inbox
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
            let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }

            before do
              note.collection_id = collection.id
              note.save!
            end

            it "delivers the collection" do
              perform_delivery(object: collection)
              expect_job(object_id: collection.id, object_type: 'DiscourseActivityPubCollection')
            end
          end
        end
      end
    end
  end
end