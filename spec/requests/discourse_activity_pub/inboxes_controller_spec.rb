# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::InboxesController do
  let(:category) { Fabricate(:category) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      'id': "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
      'type': 'Follow',
      'actor': {
        'id': "https://external.com/u/angus",
        'type': "Person",
        'inbox': "https://external.com/u/angus/inbox",
        'outbox': "https://external.com/u/angus/outbox"
      },
      'object': category.full_url,
    }
  end

  def post_json(custom_url: nil, custom_json: nil, custom_content_header: nil)
    post "#{custom_url || category.url}/inbox", headers: {
      "RAW_POST_DATA" => (custom_json || json).to_json,
      "Content-Type" => custom_content_header || DiscourseActivityPub::JsonLd.content_type_header
    }
  end

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.activity.error.#{key}")] }
  end

  describe "#create" do
    context "without activity pub enabled" do
      it "returns a not enabled error" do
        post_json
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(build_error(("not_enabled")))
      end
    end

    context "with activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = true
      end

      context "with login required" do
        before do
          SiteSetting.login_required = true
        end

        it "returns a not enabled error" do
          post_json
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(build_error(("not_enabled")))
        end
      end

      context "without a valid model" do
        it "returns a not found error" do
          post_json(custom_url: "#{category.full_url.sub(category.id.to_s, (category.id + 1).to_s)}/inboxes")
          expect(response.status).to eq(404)
          expect(response.parsed_body).to eq(build_error(("not_found")))
        end
      end

      context "without a public model" do
        before do
          category.set_permissions(admins: :full)
          category.save!
        end

        it "returns a not available error" do
          post_json
          expect(response.status).to eq(401)
          expect(response.parsed_body).to eq(build_error(("not_available")))
        end
      end

      context "without activity pub enabled on model" do
        it "returns a not enabled error" do
          post_json
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(build_error(("not_enabled")))
        end
      end

      context "with activity pub enabled on model" do
        before do
          category.activity_pub_enable!
        end

        context "with invalid headers" do
          it "returns a json not valid error" do
            post_json(custom_content_header: "application/json")
            expect(response.status).to eq(422)
            expect(response.parsed_body).to eq(build_error(("json_not_valid")))
          end
        end

        context "with invalid activity json" do
          it "returns a json not valid error" do
            json['@context'] = "https://www.w3.org/2018/credentials/v1"
            post_json(custom_json: json)
            expect(response.status).to eq(422)
            expect(response.parsed_body).to eq(build_error(("json_not_valid")))
          end
        end

        context "with valid activity json" do
          it "enqueues json processing" do
            post_json
            expect(response.status).to eq(202)
            args = {
              json: json.with_indifferent_access
            }
            expect(
              job_enqueued?(job: :discourse_activity_pub_process, args: args)
            ).to eq(true)
          end

          it "rate limits requests" do
            SiteSetting.activity_pub_rate_limit_post_to_inbox_per_minute = 1
            RateLimiter.enable
            RateLimiter.clear_all!

            post_json
            post_json
            expect(response.status).to eq(429)
          end
        end
      end
    end
  end
end
