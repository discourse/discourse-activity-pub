# frozen_string_literal: true

RSpec.describe Post do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post1) { Fabricate(:post, topic: topic) }
  let!(:post2) { Fabricate(:post, topic: topic) }

  it { is_expected.to have_one(:activity_pub_object) }

  describe "#activity_pub_enabled" do
    context "with activity pub plugin enabled" do
      context "with activity pub ready on category" do
        before do
          toggle_activity_pub(category, callbacks: true)
        end

        context "when first post in topic" do
          it { expect(post1.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(post2.activity_pub_enabled).to eq(false) }
        end
      end

      context "with activity pub not ready on category" do
        it { expect(post1.activity_pub_enabled).to eq(false) }
      end
    end

    context "with activity pub plugin disabled" do
      it { expect(post1.activity_pub_enabled).to eq(false) }
    end
  end

  describe "#activity_pub_publish_state" do
    let(:group) { Fabricate(:group) }

    before do
      category.update(reviewable_by_group_id: group.id)
    end

    context "with activity pub ready on category" do
      before do
        toggle_activity_pub(category, callbacks: true)
      end

      it "publishes status only to staff and category moderators" do
        message = MessageBus.track_publish("/activity-pub") do
          post1.activity_pub_publish_state
        end.first
        expect(message.group_ids).to eq(
          [Group::AUTO_GROUPS[:staff], category.reviewable_by_group_id]
        )
      end

      context "with status changes" do
        before do
          freeze_time

          post1.custom_fields['activity_pub_published_at'] = 2.days.ago.iso8601(3)
          post1.custom_fields['activity_pub_deleted_at'] = Time.now.iso8601(3)
          post1.save_custom_fields(true)
        end

        it "publishes the correct status" do
          message = MessageBus.track_publish("/activity-pub") do
            post1.activity_pub_publish_state
          end.first
          expect(message.data[:model][:id]).to eq(post1.id)
          expect(message.data[:model][:type]).to eq("post")
          expect(message.data[:model][:published_at]).to eq(2.days.ago.iso8601(3))
          expect(message.data[:model][:deleted_at]).to eq(Time.now.iso8601(3))
        end
      end
    end
  end
end
