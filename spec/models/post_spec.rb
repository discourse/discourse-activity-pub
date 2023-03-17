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
          category.activity_pub_enable!
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

  describe "#activity_pub_content" do
    it "respects the site setting for note excerpts" do
      SiteSetting.activity_pub_note_excerpt_maxlength = 10
      expected_excerpt = "This is a &hellip;"
      post = Fabricate(:post_with_long_raw_content)
      post.rebake!
      excerpt = post.activity_pub_content
      expect(excerpt).to eq(expected_excerpt)
    end
  end
end
