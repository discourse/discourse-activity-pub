# frozen_string_literal: true

RSpec.describe DiscourseActivityPubFollow do
  fab!(:follower, :discourse_activity_pub_actor_group)
  fab!(:followed) { Fabricate(:discourse_activity_pub_actor_person, local: false) }

  describe "#create" do
    it "does not allow duplicate follower and followed pairs" do
      Fabricate(:discourse_activity_pub_follow, follower: follower, followed: followed)

      duplicate = described_class.new(follower: follower, followed: followed)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:follower_id]).to be_present
    end
  end
end
