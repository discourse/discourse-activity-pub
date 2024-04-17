# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Undo do
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:activity) do
    Fabricate(:discourse_activity_pub_activity_follow, actor: person, object: group)
  end
  let!(:follow) { Fabricate(:discourse_activity_pub_follow, follower: person, followed: group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe "#process" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(group.model, callbacks: true) }

      context "with an Undo of a Follow" do
        let(:json) { build_activity_json(actor: person, object: activity, type: "Undo") }

        before { perform_process(json) }

        it "un-does the effects of the activity" do
          expect(
            DiscourseActivityPubFollow.exists?(follower_id: person.id, followed_id: group.id),
          ).to be(false)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: json[:id],
              ap_type: "Undo",
              actor_id: person.id,
              object_id: activity.id,
              object_type: activity.class.name,
            ),
          ).to be(true)
        end
      end

      context "with an Undo of a Like" do
        let!(:user) { Fabricate(:user) }
        let!(:topic) { Fabricate(:topic, category: group.model) }
        let!(:post) { Fabricate(:post, topic: topic) }
        let!(:like) do
          Fabricate(
            :post_action,
            user: user,
            post: post,
            post_action_type_id: PostActionType.types[:like],
          )
        end
        let!(:person) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
        let!(:activity) do
          Fabricate(:discourse_activity_pub_activity_like, actor: person, object: note)
        end
        let(:json) { build_activity_json(actor: person, object: activity, type: "Undo") }

        before { perform_process(json) }

        it "un-does the effects of the activity" do
          expect(
            PostAction.exists?(
              post_id: post.id,
              user_id: user.id,
              post_action_type_id: PostActionType.types[:like],
            ),
          ).to be(false)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: json[:id],
              ap_type: "Undo",
              actor_id: person.id,
              object_id: activity.id,
              object_type: activity.class.name,
            ),
          ).to be(true)
        end
      end

      context "with an invalid undo" do
        let!(:another_person) { Fabricate(:discourse_activity_pub_actor_person) }
        let!(:another_activity) do
          Fabricate(:discourse_activity_pub_activity_follow, actor: another_person, object: group)
        end
        let!(:another_follow) do
          Fabricate(:discourse_activity_pub_follow, follower: another_person, followed: group)
        end

        let(:json) { build_activity_json(actor: person, object: another_activity, type: "Undo") }

        it "does not undo the effects of the activity" do
          expect(
            DiscourseActivityPubFollow.exists?(
              follower_id: another_person.id,
              followed_id: group.id,
            ),
          ).to be(true)
        end

        it "does not create an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: json[:id],
              ap_type: "Undo",
              actor_id: person.id,
              object_id: another_activity.id,
              object_type: another_activity.class.name,
            ),
          ).to be(false)
        end

        context "with verbose logging enabled" do
          before do
            setup_logging
            perform_process(json)
          end
          after { teardown_logging }

          it "logs a warning" do
            expect(@fake_logger.warnings).to include(
              build_process_warning("undo_actor_must_match_object_actor", json["id"]),
            )
          end
        end
      end
    end
  end
end
