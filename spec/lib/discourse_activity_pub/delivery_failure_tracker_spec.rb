# frozen_string_literal: true

require 'rails_helper'

describe DiscourseActivityPub::DeliveryFailureTracker do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }
  subject { described_class.new(actor.inbox) }

  after do
    Discourse.redis.flushdb
  end

  describe '#track_success' do
    before do
      subject.track_failure
      subject.track_success
    end

    it 'marks URL as available again' do
      expect(subject.domain_available?).to eq(true)
    end

    it 'resets days to 0' do
      expect(subject.days).to eq(0)
    end
  end

  describe '#track_failure' do
    it 'marks domain as unavailable after 7 days of being called' do
      6.times { |i| Discourse.redis.sadd("discourse_activity_pub_exhausted_deliveries:#{actor.domain}", [i]) }
      subject.track_failure

      expect(subject.days).to eq(7)
      expect(subject.domain_available?).to eq(false)
    end

    it 'repeated calls on the same day do not count' do
      subject.track_failure
      subject.track_failure

      expect(subject.days).to eq(1)
    end
  end
end
