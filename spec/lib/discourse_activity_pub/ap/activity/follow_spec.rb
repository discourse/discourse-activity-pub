# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Follow do
  let(:category) { Fabricate(:category) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
      type: described_class.type,
      actor: {
        id: "https://external.com/u/angus",
        type: "Person",
        inbox: "https://external.com/u/angus/inbox",
        outbox: "https://external.com/u/angus/outbox"
      },
      object: category.full_url,
    }.with_indifferent_access
  end

  def build_response(activity)
    DiscourseActivityPub::AP::Activity::Response.new(activity: activity)
  end

  def serialize_response(response)
    DiscourseActivityPub::AP::Activity::ResponseSerializer.new(response, root: false).as_json
  end

  def build_warning(key, object_id)
    action = I18n.t("discourse_activity_pub.activity.warning.failed_to_process", object_id: object_id)
    message = I18n.t("discourse_activity_pub.activity.warning.#{key}")
    "[Discourse Activity Pub] #{action}: #{message}"
  end

  describe '#process' do

    def perform_process(json)
      klass = described_class.new
      klass.json = json
      klass.process
    end

    context "with a valid follow" do
      context 'without a successful json process' do
        before do
          DiscourseActivityPub::AP::Activity.any_instance.stubs(:process_json).returns(false)
        end

        it "does not create a follower" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: described_class.type,
              object_id: category.id,
              object_type: 'Category'
            )
          ).to eq(false)
        end
      end

      context 'with activity pub enabled' do
        before do
          category.custom_fields["activity_pub_enabled"] = true
          category.save!
        end

        context 'when not following' do
          before do
            perform_process(json)
            @actor = DiscourseActivityPubActor.find_by(uid: json['actor']['id'])
            @activity = DiscourseActivityPubActivity.find_by(uid: json['id'])
          end

          it 'creates an actor' do
            expect(@actor.present?).to eq(true)
          end

          it 'creates an activity' do
            expect(
              DiscourseActivityPubActivity.exists?(
                ap_type: described_class.type,
                actor_id: @actor.id
              )
            ).to eq(true)
          end

          it 'creates a follow' do
            expect(
              DiscourseActivityPubFollow.exists?(
                follower_id: @actor.id,
                followed_id: category.activity_pub_actor.id
              )
            ).to eq(true)
          end

          it 'enqueues an accept' do
            response_actor = category.activity_pub_actor
            response_activity = DiscourseActivityPubActivity.find_by(
              ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
              actor_id: response_actor.id,
              object_id: @activity.id
            )
            args = {
              url: @actor.inbox,
              payload: serialize_response(build_response(response_activity))
            }
            expect(
              job_enqueued?(job: :discourse_activity_pub_deliver, args: args)
            ).to eq(true)
          end
        end

        context 'when already following' do
          let!(:activity) do
            Fabricate(:discourse_activity_pub_activity_follow,
              object: category.activity_pub_actor
            )
          end
          let!(:follow) do
            Fabricate(:discourse_activity_pub_follow,
              follower: activity.actor,
              followed: activity.object
            )
          end

          before do
            json['actor']['id'] = activity.actor.uid
            json['object'] = activity.object.model.full_url
            perform_process(json)
          end

          it 'creates an activity' do
            expect(
              DiscourseActivityPubActivity.exists?(uid: json['id'])
            ).to eq(true)
          end

          it 'does not duplicate actors' do
            expect(DiscourseActivityPubActor.where(uid: activity.actor.uid).size).to eq(1)
          end

          it 'does not duplicate follows' do
            expect(
              DiscourseActivityPubFollow.where(
                follower_id: activity.actor.id,
                followed_id: activity.object.id
              ).size
            ).to eq(1)
          end

          it 'enqueues a reject' do
            reject = DiscourseActivityPubActivity.find_by(
              ap_type: DiscourseActivityPub::AP::Activity::Reject.type,
              actor_id: activity.object.id,
              object_id: DiscourseActivityPubActivity.find_by(uid: json['id']).id
            )
            expect(reject.present?).to eq(true)

            args = {
              url: activity.actor.inbox,
              payload: serialize_response(build_response(reject))
            }
            expect(
              job_enqueued?(job: :discourse_activity_pub_deliver, args: args)
            ).to eq(true)
          end
        end
      end
    end
  end
end
