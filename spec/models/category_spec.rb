# frozen_string_literal: true

RSpec.describe Category do
  let(:category) { Fabricate(:category) }

  it { is_expected.to have_one(:activity_pub_actor).dependent(:destroy) }

  describe "#activity_pub_ready?" do
    context "with category activity pub enabled" do
      before do
        toggle_activity_pub(category)
      end

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

  describe "#save_custom_fields" do
    it "does nothing if activity pub plugin disabled" do
      SiteSetting.activity_pub_enabled = false
      expect do
        category.custom_fields['activity_pub_enabled'] = true
        category.save_custom_fields
      end.not_to raise_error
    end

    it "raises if activity pub enabled without a username" do
      expect do
        category.custom_fields['activity_pub_enabled'] = true
        category.save_custom_fields
      end.to raise_error(ActiveRecord::Rollback)
    end

    it "raises if activity pub username changed after activity pub actor set" do
      toggle_activity_pub(category)
      category.save!
      expect(category.activity_pub_actor.present?).to eq(true)

      expect do
        category.custom_fields['activity_pub_username'] = 'new_username'
        category.save_custom_fields
      end.to raise_error(ActiveRecord::Rollback)
    end

    it "validates activity pub username if changed" do
      DiscourseActivityPub::UsernameValidator
        .expects(:perform_validation)
        .with(category, 'activity_pub_username')
        .once
      toggle_activity_pub(category)
    end

    it "raises if username is invalid" do
      expect do
        toggle_activity_pub(category, username: "abc象")
      end.to raise_error(ActiveRecord::Rollback)
    end

    it "raises if username is not unique for local actors" do
      category2 = Fabricate(:category)
      toggle_activity_pub(category2, username: "general", callbacks: true)

      expect do
        toggle_activity_pub(category, username: "general")
      end.to raise_error(ActiveRecord::Rollback)
    end

    it "publishes activity pub state if activity_pub_enabled is changed" do
      message = MessageBus.track_publish("/activity-pub") do
        toggle_activity_pub(category)
      end.first
      expect(message.data).to eq(
        { model: { id: category.id, type: "category", ready: false, enabled: true } }
      )
    end
  end

  describe "#activity_pub_publish_state" do
    it "publishes status to all users" do
      message = MessageBus.track_publish("/activity-pub") do
        category.activity_pub_publish_state
      end.first
      expect(message.group_ids).to eq(nil)
    end
  end
end
