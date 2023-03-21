# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Compose do
  let(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
  let(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }

  describe "#deliver" do
    before do
      Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor)
      Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: actor)
    end

    it "enqueues deliveries to actor's followers" do
      stored = Fabricate(:discourse_activity_pub_activity_create, actor: actor)
      ap = DiscourseActivityPub::AP::Activity::Create.new(stored: stored)
      ap.deliver

      expect(
        job_enqueued?(job: :discourse_activity_pub_deliver, args: {
          url: follower1.inbox,
          payload: ap.json
        })
      ).to eq(true)
      expect(
        job_enqueued?(job: :discourse_activity_pub_deliver, args: {
          url: follower2.inbox,
          payload: ap.json
        })
      ).to eq(true)
    end
  end
end