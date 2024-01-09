# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Reject do
  let(:category) { Fabricate(:category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe "#process" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(category, callbacks: true) }

      context "with a followed actor" do
        let!(:followed_actor_id) { "https://mastodon.pavilion.tech/users/angus" }
        let!(:followed_actor) do
          Fabricate(:discourse_activity_pub_actor_person, ap_id: followed_actor_id, local: false)
        end

        context "with a follow activity" do
          let!(:follow) do
            Fabricate(
              :discourse_activity_pub_activity_follow,
              actor: category.activity_pub_actor,
              object: followed_actor,
            )
          end

          before do
            json =
              build_activity_json(
                id: "#{followed_actor_id}#accepts/follows/",
                type: "Reject",
                actor: followed_actor,
                object: follow.ap.json,
              )
            perform_process(json)
          end

          it "creates an activity" do
            expect(
              DiscourseActivityPubActivity.exists?(
                ap_type: described_class.type,
                actor_id: followed_actor.id,
              ),
            ).to eq(true)
          end

          it "does not create a follow" do
            expect(
              DiscourseActivityPubFollow.exists?(
                followed_id: followed_actor.id,
                follower_id: category.activity_pub_actor.id,
              ),
            ).to eq(false)
          end
        end
      end
    end
  end
end
