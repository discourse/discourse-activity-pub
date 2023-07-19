# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Undo do
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_follow, actor: person, object: group) }
  let!(:follow) { Fabricate(:discourse_activity_pub_follow, follower: person, followed: group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe '#process' do

    def perform_process(json)
      klass = described_class.new
      klass.json = json
      klass.process
    end

    context 'with activity pub enabled' do
      before do
        toggle_activity_pub(group.model, callbacks: true)
      end

      context "with a valid undo" do
        let(:json) { build_activity_json(actor: person, object: activity, type: 'Undo') }

        before do
          perform_process(json)
        end

        it "un-does the effects of the activity" do
          expect(
            DiscourseActivityPubFollow.exists?(
              follower_id: person.id,
              followed_id: group.id
            )
          ).to be(false)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: json[:id],
              ap_type: "Undo",
              actor_id: person.id,
              object_id: activity.id,
              object_type: activity.class.name
            )
          ).to be(true)
        end
      end

      context "with an invalid undo" do
        let!(:another_person) { Fabricate(:discourse_activity_pub_actor_person) }
        let!(:another_activity) { Fabricate(:discourse_activity_pub_activity_follow, actor: another_person, object: group) }
        let!(:another_follow) { Fabricate(:discourse_activity_pub_follow, follower: another_person, followed: group) }

        let(:json) { build_activity_json(actor: person, object: another_activity, type: 'Undo') }

        it "does not undo the effects of the activity" do
          expect(
            DiscourseActivityPubFollow.exists?(
              follower_id: another_person.id,
              followed_id: group.id
            )
          ).to be(true)
        end

        it "does not create an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: json[:id],
              ap_type: "Undo",
              actor_id: person.id,
              object_id: another_activity.id,
              object_type: another_activity.class.name
            )
          ).to be(false)
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
          end

          before do
            @orig_logger = Rails.logger
            Rails.logger = @fake_logger = FakeLogger.new

            perform_process(json)
          end

          after do
            Rails.logger = @orig_logger
          end

          it "logs a warning" do
            expect(@fake_logger.warnings).to include(
              build_process_warning("undo_actor_must_match_object_actor", json['id'])
            )
          end
        end
      end
    end
  end
end
