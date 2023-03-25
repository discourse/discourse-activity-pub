# frozen_string_literal: true

RSpec.describe Category do
  let(:category) { Fabricate(:category) }

  it { is_expected.to have_one(:activity_pub_actor).dependent(:destroy) }
  it { is_expected.to have_many(:activity_pub_followers).dependent(:destroy) }
  it { is_expected.to have_many(:activity_pub_activities).dependent(:destroy) }

  describe "#activity_pub_enable!" do
    before do
      category.activity_pub_enable!
    end

    it "enables activity pub on the category" do
      expect(category.activity_pub_enabled).to eq(true)
    end

    it "creates an activity pub actor for the category (if it doesnt exist)" do
      expect(category.activity_pub_actor.present?).to eq(true)
    end
  end

  describe "#activity_pub_ready?" do
    context "with activity pub enabled" do
      before do
        # to avoid callbacks
        CategoryCustomField.create!(category_id: category.id, name: "activity_pub_enabled", value: "true")
        category.reload
      end

      context "without an activity pub actor" do
        it "returns false" do
          expect(category.activity_pub_ready?).to eq(false)
        end
      end

      context "with an activity pub actor" do
        let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

        it "returns true" do
          expect(category.activity_pub_ready?).to eq(true)
        end
      end
    end
  end

  describe "#save_custom_fields" do
    it "publishes activity pub state if activity_pub_enabled is changed" do
      message = MessageBus.track_publish("/activity-pub") do
        category.custom_fields['activity_pub_enabled'] = true
        category.save_custom_fields
      end.first
      expect(message.data).to eq(
        { model: { id: category.id, type: "category", ready: false, enabled: true } }
      )
    end
  end

  describe "#activity_pub_publish_state" do
    let(:group) { Fabricate(:group) }

    before do
      category.update(reviewable_by_group_id: group.id)
    end

    context "with activity_pub_show_status disabled" do
      before do
        category.custom_fields['activity_pub_show_status'] = false
        category.save_custom_fields
      end

      it "publishes status only to staff and category moderators" do
        message = MessageBus.track_publish("/activity-pub") do
          category.activity_pub_publish_state
        end.first
        expect(message.group_ids).to eq(
          [Group::AUTO_GROUPS[:staff], category.reviewable_by_group_id]
        )
      end
    end

    context "with activity_pub_show_status enabled" do
      before do
        category.custom_fields['activity_pub_show_status'] = true
        category.save_custom_fields
      end

      it "publishes status to all users" do
        message = MessageBus.track_publish("/activity-pub") do
          category.activity_pub_publish_state
        end.first
        expect(message.group_ids).to eq(nil)
      end
    end
  end
end
