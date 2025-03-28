# frozen_string_literal: true

describe DiscourseActivityPub::DeliveryFailureTracker do
  subject(:tracker) { described_class.new(actor.inbox) }

  let!(:domain) { "example.com" }
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, domain: domain) }

  before { 10.times { Fabricate(:discourse_activity_pub_actor_person, domain: domain) } }
  after { Discourse.redis.flushdb }

  describe "#track_success" do
    it "marks URL as available again" do
      tracker.track_failure
      tracker.track_success
      expect(tracker.domain_available?).to eq(true)
    end

    it "resets days to 0" do
      tracker.track_failure
      tracker.track_success
      expect(tracker.days).to eq(0)
    end

    it "doesn't call update_all if domain is available" do
      DiscourseActivityPubActor.expects(:update_all).never
      tracker.track_success
    end
  end

  describe "#track_failure" do
    it "marks domain as unavailable after 7 days of being called" do
      6.times do |i|
        Discourse.redis.sadd("discourse_activity_pub_exhausted_deliveries:#{actor.domain}", [i])
      end
      tracker.track_failure

      expect(tracker.days).to eq(7)
      expect(tracker.domain_available?).to eq(false)
    end

    it "repeated calls on the same day do not count" do
      tracker.track_failure
      tracker.track_failure

      expect(tracker.days).to eq(1)
    end
  end
end
