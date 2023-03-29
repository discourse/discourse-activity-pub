# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Follow do
  let(:category) { Fabricate(:category) }

  def build_response(activity)
    DiscourseActivityPub::AP::Activity::Response.new(stored: activity)
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
          toggle_activity_pub(category, with_actor: true)
        end

        context 'when not following' do
          before do
            json = build_follow_json(category.activity_pub_actor)
            perform_process(json)
            @actor = DiscourseActivityPubActor.find_by(ap_id: json['actor']['id'])
            @activity = DiscourseActivityPubActivity.find_by(ap_id: json['id'])
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
          let!(:existing_activity) do
            Fabricate(:discourse_activity_pub_activity_follow,
              object: category.activity_pub_actor
            )
          end
          let!(:follow) do
            Fabricate(:discourse_activity_pub_follow,
              follower: existing_activity.actor,
              followed: existing_activity.object
            )
          end

          before do
            json = build_follow_json(category.activity_pub_actor)
            json['actor']['id'] = existing_activity.actor.ap_id
            json['object'] = existing_activity.object.ap_id
            perform_process(json)
            @new_activity = DiscourseActivityPubActivity.find_by(ap_id: json['id'])
          end

          it 'creates an activity' do
            expect(@new_activity.present?).to eq(true)
          end

          it 'does not duplicate actors' do
            expect(DiscourseActivityPubActor.where(ap_id: existing_activity.actor.ap_id).size).to eq(1)
          end

          it 'does not duplicate follows' do
            expect(
              DiscourseActivityPubFollow.where(
                follower_id: existing_activity.actor.id,
                followed_id: existing_activity.object.id
              ).size
            ).to eq(1)
          end

          it 'enqueues a reject' do
            reject = DiscourseActivityPubActivity.find_by(
              ap_type: DiscourseActivityPub::AP::Activity::Reject.type,
              actor_id: @new_activity.object.id,
              object_id: @new_activity.id
            )
            expect(reject.present?).to eq(true)

            args = {
              url: @new_activity.actor.inbox,
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
