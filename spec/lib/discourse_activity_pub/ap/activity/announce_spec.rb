# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Announce do
  let(:category) { Fabricate(:category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe '#process' do
    let!(:followed_actor_id) { "https://mastodon.pavilion.tech/groups/1" }
    let!(:followed_actor) { Fabricate(:discourse_activity_pub_actor_group, ap_id: followed_actor_id, local: false) }

    context 'with activity pub enabled' do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
      end

      context "when announced by an actor being followed" do
        let!(:create_json) {
          build_activity_json(
            type: "Create",
            to: [category.activity_pub_actor.ap_id]
          )
        }
        let!(:announce_json) { 
          build_activity_json(
            id: "#{followed_actor_id}#note/1",
            type: 'Announce',
            actor: followed_actor,
            object: create_json,
            to: [category.activity_pub_actor.ap_id]
          )
        }
        let!(:follow) {
          Fabricate(:discourse_activity_pub_follow,
            follower: category.activity_pub_actor,
            followed: followed_actor
          )
        }

        before do
          perform_process(announce_json)
          @create_actor = DiscourseActivityPubActor.find_by(ap_id: create_json[:actor][:id])
        end

        it 'does not create an announce activity' do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: described_class.type,
              actor_id: followed_actor.id
            )
          ).to eq(false)
        end

        it "creates the announced activity actor" do
          expect(@create_actor.present?).to eq(true)
        end

        it 'creates the announced activity' do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: 'Create',
              actor_id: @create_actor.id
            )
          ).to eq(true)
        end
      end

      context "when announced by an actor not being followed" do
        let!(:create_json) {
          build_activity_json(
            type: "Create",
            to: [category.activity_pub_actor.ap_id]
          )
        }
        let!(:announce_json) { 
          build_activity_json(
            id: "#{followed_actor_id}#note/1",
            type: 'Announce',
            actor: followed_actor,
            object: create_json,
            to: [category.activity_pub_actor.ap_id]
          )
        }

        before do
          perform_process(announce_json)
          @create_actor = DiscourseActivityPubActor.find_by(ap_id: create_json[:actor][:id])
        end

        it 'does not create the announce activity' do
          perform_process(announce_json)
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: described_class.type,
              actor_id: followed_actor.id
            )
          ).to eq(false)
        end

        it "does not create the announced activity actor" do
          expect(@create_actor.present?).to eq(false)
        end

        it 'does not create the announced activity' do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: 'Create',
            )
          ).to eq(false)
        end
      end
    end
  end
end
