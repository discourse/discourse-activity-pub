# frozen_string_literal: true

RSpec.describe Category do
  let(:category) { Fabricate(:category) }

  it { is_expected.to have_one(:activity_pub_actor).dependent(:destroy) }

  describe "#activity_pub_ready?" do
    context "with category activity pub enabled" do
      before { toggle_activity_pub(category) }

      context "without an activity pub actor" do
        it "returns false" do
          expect(category.activity_pub_ready?).to eq(false)
        end
      end

      context "with an activity pub actor" do
        let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

        it "returns true" do
          expect(category.reload.activity_pub_ready?).to eq(true)
        end

        context "with category read restricted" do
          before do
            category.set_permissions(staff: :full)
            category.save!
          end

          it "returns false" do
            expect(category.reload.activity_pub_ready?).to eq(false)
          end
        end
      end
    end
  end

  describe "#activity_pub_publish_state" do
    it "publishes status to all users" do
      message =
        MessageBus.track_publish("/activity-pub") { category.activity_pub_publish_state }.first
      expect(message.group_ids).to eq(nil)
    end
  end
end
