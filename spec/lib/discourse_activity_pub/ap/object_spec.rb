# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Object do
  describe "#factory" do
    let(:category) { Fabricate(:category) }
    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
        type: DiscourseActivityPub::AP::Activity::Follow.type,
        actor: "https://external.com/u/angus",
        object: category.full_url,
      }.with_indifferent_access
    end

    it "generates an AP object from json" do
      expect(
        described_class.factory(json)
      ).to be_a(DiscourseActivityPub::AP::Activity::Follow)
    end
  end
end