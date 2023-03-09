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
end
