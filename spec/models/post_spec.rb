# frozen_string_literal: true

RSpec.describe Post do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post1) { Fabricate(:post, topic: topic) }
  let!(:post2) { Fabricate(:post, topic: topic) }

  it { is_expected.to have_many(:activity_pub_objects) }

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
end
