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
          actor: opts[:actor] || person,
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
        before { setup_logging }
        after { teardown_logging }

        it "returns a json not valid error" do
          body = post_body
          body["@context"] = "https://www.w3.org/2018/credentials/v1"
          post_to_inbox(group, body: body)
          expect_request_error(response, "json_not_valid", 422)
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
        before { setup_logging }
        after { teardown_logging }

        it "returns the right unauthorized error" do
          post_to_inbox(group, body: post_body)
          expect_request_error(response, "not_signed", 401)
        end
      end

      context "with a signature" do
        context "with missing signature params" do
          let(:headers) { build_post_headers(key_id: "") }

          before { setup_logging }
          after { teardown_logging }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect_request_error(response, "missing_signature_params", 401)
          end
        end

        context "with an unsupported algorithm" do
          let(:headers) { build_post_headers(params: { algorithm: "hmac-sha256" }) }

          before { setup_logging }
          after { teardown_logging }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect_request_error(response, "unsupported_signature_algorithm", 401)
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

            before { setup_logging }
            after { teardown_logging }

            it "returns the right unauthorized error" do
              post_to_inbox(group, body: post_body, headers: headers)
              expect_request_error(
                response,
                "invalid_date_header",
                401,
                reason: "not RFC 2616 compliant date: \"not a date\"",
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

            before { setup_logging }
            after { teardown_logging }

            it "returns the right unauthorized error" do
              post_to_inbox(group, body: post_body, headers: headers)
              expect_request_error(response, "stale_request", 401)
            end
          end
        end

        context "with a missing Signature pseudo-param" do
          let(:headers) { build_post_headers(params: { "headers" => "(request-target) host" }) }

          before { setup_logging }
          after { teardown_logging }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect_request_error(response, "date_must_be_signed", 401)
          end
        end

        context "with an invalid public key" do
          let(:headers) { build_post_headers }

          before do
            person.public_key = "not a real key"
            person.save!
            setup_logging
          end

          after { teardown_logging }

          it "attempts to refresh actor and returns the right error" do
            DiscourseActivityPubActor.any_instance.expects(:refresh_remote!).once.returns(nil)
            post_to_inbox(group, body: post_body, headers: headers)
            expect_request_error(response, "signature_verification_failed", 401, id: person.ap_id)
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
            expect_request_error(response, "signature_verification_failed", 401, id: person.ap_id)
          end
        end

        context "with a valid public key" do
          let(:headers) { build_post_headers }

          it "succeeds" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect(response.status).to eq(202)
          end

          context "with an actor from an allowed domain" do
            before { SiteSetting.activity_pub_allowed_request_origins = "remote.com" }

            it "allows allowed domains" do
              actor =
                Fabricate(
                  :discourse_activity_pub_actor_person,
                  public_key: keypair.public_key.to_pem,
                  actor_domain: "remote.com",
                )
              post_to_inbox(group, body: post_body, headers: build_post_headers(actor: actor))
              expect(response.status).to eq(202)
            end

            it "blocks not allowed domains" do
              actor =
                Fabricate(
                  :discourse_activity_pub_actor_person,
                  public_key: keypair.public_key.to_pem,
                  actor_domain: "another-remote.com",
                )
              post_to_inbox(group, body: post_body, headers: build_post_headers(actor: actor))
              expect(response.status).to eq(403)
            end
          end

          context "with blocked domains" do
            before { SiteSetting.activity_pub_blocked_request_origins = "remote.com" }

            it "blocks blocked domains" do
              actor =
                Fabricate(
                  :discourse_activity_pub_actor_person,
                  public_key: keypair.public_key.to_pem,
                  actor_domain: "remote.com",
                )
              post_to_inbox(group, body: post_body, headers: build_post_headers(actor: actor))
              expect(response.status).to eq(403)
            end

            it "allows unblocked domains" do
              actor =
                Fabricate(
                  :discourse_activity_pub_actor_person,
                  public_key: keypair.public_key.to_pem,
                  actor_domain: "another-remote.com",
                )
              post_to_inbox(group, body: post_body, headers: build_post_headers(actor: actor))
              expect(response.status).to eq(202)
            end
          end
        end

        context "with a new actor" do
          let!(:new_person) { build_actor_json(public_key: keypair.public_key.to_pem) }
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

          before { setup_logging }
          after { teardown_logging }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: post_body, headers: headers)
            expect_request_error(
              response,
              "invalid_digest",
              401,
              computed: digest,
              digest: invalid_digest,
            )
          end
        end
      end
    end
  end
end
