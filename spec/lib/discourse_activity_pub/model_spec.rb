# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Model do
  describe "#find_by_url" do
    let(:category) { Fabricate(:category) }

    it "finds a local model by its url" do
      expect(
        described_class.find_by_url(category.activity_pub_id)
      ).to eq(category)
    end
  end
end