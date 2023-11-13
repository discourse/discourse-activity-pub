# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::FollowHandler do

  def perform(actor, handle)
    DiscourseActivityPub::FollowHandler.perform(actor, handle)
  end

  describe "#perform" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

    context "with a local handle" do
      let!(:handle) { "username@#{DiscourseActivityPub.host}" }

      it "returns false" do
        expect(perform(actor, handle)).to eq(false)
      end
    end

    context "with a remote handle" do
      let!(:handle) { "username@external.com" }

      context "when actor being followed cant be found" do
        before do
          DiscourseActivityPubActor.expects(:find_by_handle).with(handle).returns(nil)
        end

        it "returns false" do
          expect(perform(actor, handle)).to eq(false)
        end
      end

      context "when actor being followed can be found" do
        let!(:follow_actor) { Fabricate(:discourse_activity_pub_actor_person) }

        before do
          DiscourseActivityPubActor.expects(:find_by_handle).with(handle).returns(follow_actor)
        end

        it "creates a follow activity" do
          perform(actor, handle)
          expect(
            DiscourseActivityPubActivity.exists?(
                local: true,
                actor_id: actor.id,
                object_id: follow_actor.id,
                object_type: follow_actor.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
            )
          ).to eq(true)
        end

        it "performs the right delivery" do
          expect_delivery(
            actor: actor,
            object_type: DiscourseActivityPub::AP::Activity::Follow.type
          )
          perform(actor, handle)
        end
      end
    end
  end
end