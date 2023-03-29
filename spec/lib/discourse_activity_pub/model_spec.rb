# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Model do
  describe "#find_by_url" do
    let(:category) { Fabricate(:category) }

    it "finds a local model by its url" do
      expect(
        described_class.find_by_url(category.full_url)
      ).to eq(category)
    end
  end
end