# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::InboxesController do
  let!(:keypair) { OpenSSL::PKey::RSA.new(2048) }
  let!(:person) do
    Fabricate(:discourse_activity_pub_actor_person, public_key: keypair.public_key.to_pem)
  end
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ActorsController }

  describe "#create" do
    let!(:post_body) { build_activity_json(type: "Follow", object: group) }
    let!(:digest) { Digest::SHA256.base64digest(post_body.to_json) }

    def build_post_headers(opts = {})
      headers = {
        :verb => "post",
        :path => DiscourseActivityPub::URI.parse(group.inbox).path,
        "Digest" => "SHA-256=#{digest}",
      }.merge(opts[:headers] || {})

      build_headers(
        **opts.except(:headers).merge(
          object: group,
          actor: person,
          keypair: keypair,
          headers: headers,
          verb: "post",
          path: DiscourseActivityPub::URI.parse(group.inbox).path,
        ),
      )
    end

    before { toggle_activity_pub(group.model) }

    context "without signature required" do
      before { SiteSetting.activity_pub_require_signed_requests = false }

      context "with invalid activity json" do
        it "returns a json not valid error" do
          body = post_body
          body["@context"] = "https://www.w3.org/2018/credentials/v1"
          post_to_inbox(group, body: body)
          expect(response.status).to eq(422)
          expect(response.parsed_body).to eq(activity_request_error("json_not_valid"))
        end
      end

      context "with valid activity json" do
        it "enqueues json processing" do
          post_to_inbox(group, body: post_body)
          expect(response.status).to eq(202)
          expect(
            job_enqueued?(job: :discourse_activity_pub_process, args: { json: post_body }),
          ).to eq(true)
        end

        it "rate limits requests" do
          SiteSetting.activity_pub_rate_limit_post_to_inbox_per_minute = 1
          RateLimiter.enable
          RateLimiter.clear_all_global!

          post_to_inbox(group, body: post_body)
          post_to_inbox(group, body: post_body)
          expect(response.status).to eq(429)
        end
      end
    end

    context "with signature required" do
      before { SiteSetting.activity_pub_require_signed_requests = true }

      context "without a signature" do
        it "returns the right unauthorized error" do
          post_to_inbox(group, body: post_body)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq(
            [I18n.t("discourse_activity_pub.request.error.not_signed")],
          )
        end
      end

      context "with a signature" do
        context "with missing signature params" do
          let(:headers) { build_post_headers(key_id: "") }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [I18n.t("discourse_activity_pub.request.error.missing_signature_params")],
            )
          end
        end

        context "with an unsupported algorithm" do
          let(:headers) { build_post_headers(params: { algorithm: "hmac-sha256" }) }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [I18n.t("discourse_activity_pub.request.error.unsupported_signature_algorithm")],
            )
          end
        end

        context "with a rsa-sha256 algorithm" do
          let(:headers) { build_post_headers(params: { algorithm: "rsa-sha256" }) }

          it "suceeds" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(202)
          end

          context "with an invalid date" do
            let(:headers) do
              build_post_headers(
                params: {
                  algorithm: "rsa-sha256",
                },
                headers: {
                  "Date" => "not a date",
                },
              )
            end

            it "returns the right unauthorized error" do
              post_to_inbox(group, body: post_body, headers: headers)
              expect(response.status).to eq(401)
              expect(response.parsed_body["errors"]).to eq(
                [
                  I18n.t(
                    "discourse_activity_pub.request.error.invalid_date_header",
                    reason: "not RFC 2616 compliant date: \"not a date\"",
                  ),
                ],
              )
            end
          end

          context "with a stale date" do
            let(:headers) do
              build_post_headers(
                params: {
                  algorithm: "rsa-sha256",
                },
                headers: {
                  "Date" => 2.days.ago.utc.httpdate,
                },
              )
            end

            it "returns the right unauthorized error" do
              post_to_inbox(group, body: post_body, headers: headers)
              expect(response.status).to eq(401)
              expect(response.parsed_body["errors"]).to eq(
                [I18n.t("discourse_activity_pub.request.error.stale_request")],
              )
            end
          end
        end

        context "with a missing Signature pseudo-param" do
          let(:headers) { build_post_headers(params: { "headers" => "(request-target) host" }) }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [I18n.t("discourse_activity_pub.request.error.date_must_be_signed")],
            )
          end
        end

        context "with an invalid public key" do
          let(:headers) { build_post_headers }

          before do
            person.public_key = "not a real key"
            person.save!
          end

          it "attempts to refresh actor and returns the right error" do
            DiscourseActivityPubActor.any_instance.expects(:refresh_remote!).once.returns(nil)
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [
                I18n.t(
                  "discourse_activity_pub.request.error.signature_verification_failed",
                  id: person.ap_id,
                ),
              ],
            )
          end

          it "succeeds if actor is refreshed with a valid public key" do
            person_ap_json = person.ap.json
            person_ap_json["publicKey"] = {
              id: signature_key_id(person),
              owner: person.ap_id,
              publicKeyPem: keypair.public_key.to_pem,
            }

            stub_request(:get, person.ap_id).to_return(
              body: person_ap_json.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
              status: 200,
            )

            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(202)
          end

          it "fails with the right error if the actor is not refreshed with a valid public key" do
            stub_request(:get, person.ap_id).to_return(body: nil, status: 400)

            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [
                I18n.t(
                  "discourse_activity_pub.request.error.signature_verification_failed",
                  id: person.ap_id,
                ),
              ],
            )
          end
        end

        context "with a valid public key" do
          let(:headers) { build_post_headers }

          it "succeeds" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(202)
          end
        end

        context "with a new actor" do
          let!(:new_person) { build_actor_json(keypair.public_key.to_pem) }
          let!(:headers) do
            build_post_headers(key_id: new_person[:publicKey][:id], keypair: keypair)
          end

          before do
            stub_request(:get, new_person[:id]).to_return(
              body: new_person.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
              status: 200,
            )
          end

          it "succeeds and creates the actor" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(202)
            expect(DiscourseActivityPubActor.exists?(ap_id: new_person[:id])).to eq(true)
          end
        end

        context "with an invalid digest" do
          let!(:invalid_digest) { Digest::SHA256.base64digest("invalid body") }
          let!(:headers) do
            build_post_headers(headers: { "Digest" => "SHA-256=#{invalid_digest}" })
          end

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq(
              [
                I18n.t(
                  "discourse_activity_pub.request.error.invalid_digest",
                  { computed: digest, digest: invalid_digest },
                ),
              ],
            )
          end
        end
      end
    end
  end
end
