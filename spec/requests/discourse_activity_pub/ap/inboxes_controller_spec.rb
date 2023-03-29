# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::InboxesController do
  let(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ActorsController }

  describe "#create" do
    before do
      @json = build_follow_json(actor)
      toggle_activity_pub(actor.model)
    end

    context "with invalid activity json" do
      it "returns a json not valid error" do
        @json['@context'] = "https://www.w3.org/2018/credentials/v1"
        post_to_inbox(actor, body: @json)
        expect(response.status).to eq(422)
        expect(response.parsed_body).to eq(activity_request_error(("json_not_valid")))
      end
    end

    context "with valid activity json" do
      it "enqueues json processing" do
        post_to_inbox(actor, body: @json)
        expect(response.status).to eq(202)
        expect(
          job_enqueued?(job: :discourse_activity_pub_process, args: {
            json: @json
          })
        ).to eq(true)
      end

      it "rate limits requests" do
        SiteSetting.activity_pub_rate_limit_post_to_inbox_per_minute = 1
        RateLimiter.enable
        RateLimiter.clear_all!

        post_to_inbox(actor, body: @json)
        post_to_inbox(actor, body: @json)
        expect(response.status).to eq(429)
      end
    end
  end
end
