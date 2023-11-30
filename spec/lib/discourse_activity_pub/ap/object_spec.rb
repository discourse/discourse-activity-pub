# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Object do
  describe "#factory" do
    it "generates an AP object from json" do
      expect(described_class.factory(build_activity_json)).to be_a(
        DiscourseActivityPub::AP::Activity::Follow,
      )
    end
  end

  describe "#json" do
    context "when AP object has storage" do
      let(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow) }

      it "generates json from storage" do
        ap = DiscourseActivityPub::AP::Activity::Follow.new(stored: follow_activity)
        expect(ap.json["id"]).to eq(follow_activity.ap_id)
        expect(ap.json["actor"]["id"]).to eq(follow_activity.actor.ap_id)
        expect(ap.json["object"]["id"]).to eq(follow_activity.object.ap_id)
      end
    end
  end
end
