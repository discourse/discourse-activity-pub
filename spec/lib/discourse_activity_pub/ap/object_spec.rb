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
        object: category.activity_pub_id,
      }.with_indifferent_access
    end

    describe "#factory" do
      it "generates an AP object from json" do
        expect(
          described_class.factory(json)
        ).to be_a(DiscourseActivityPub::AP::Activity::Follow)
      end
    end

    describe "#json" do
      context "when AP object has storage" do
        let(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow) }

        it "generates json from storage" do
          ap = DiscourseActivityPub::AP::Activity::Follow.new(stored: follow_activity)
          expect(ap.json['id']).to eq(follow_activity.uid)
          expect(ap.json['actor']['id']).to eq(follow_activity.actor.uid)
          expect(ap.json['object']['id']).to eq(follow_activity.object.uid)
        end
      end
    end
  end
end