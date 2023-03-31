# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ObjectsController do
  let(:object) { Fabricate(:discourse_activity_pub_object_note) }

  before do
    SiteSetting.activity_pub_require_signed_requests = false
  end

  context "without activity pub enabled" do
    before do
      SiteSetting.activity_pub_enabled = false
    end

    it "returns a not enabled error" do
      get_object(object)
      expect(response.status).to eq(403)
      expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
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
        get_object(object)
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
      end
    end
  end

  context "with an invalid content header" do
    let(:group) { Fabricate(:discourse_activity_pub_actor_group) }

    context "with invalid Content-Type header" do
      it "returns bad request" do
        post_to_inbox(group, headers: { "Content-Type" => "application/json" })
        expect(response.status).to eq(400)
        expect(response.parsed_body).to eq(activity_request_error("bad_request"))
      end
    end

    context "with invalid Accept header" do
      it "returns bad request" do
        get_from_outbox(group, headers: { "Accept" => "application/json" })
        expect(response.status).to eq(400)
        expect(response.parsed_body).to eq(activity_request_error("bad_request"))
      end
    end
  end

  context "with allowed domains" do
    before do
      SiteSetting.activity_pub_allowed_request_origins = "allowed.com"
    end

    it "allows allowed domains" do
      get_object(object, headers: { ORIGIN: "https://allowed.com" })
      expect(response.status).to eq(200)
    end

    it "blocks not allowed domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect(response.status).to eq(403)
    end
  end

  context "with blocked domains" do
    before do
      SiteSetting.activity_pub_blocked_request_origins = "notallowed.com"
    end

    it "blocks blocked domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect(response.status).to eq(403)
    end

    it "allows unblocked domains" do
      get_object(object, headers: { ORIGIN: "https://allowed.com" })
      expect(response.status).to eq(200)
    end
  end

  context "with signature required" do
    before do
      SiteSetting.activity_pub_require_signed_requests = true
    end

    context 'without a signature' do
      it "returns the right unauthorized error" do
        get_object(object)
        expect(response.status).to eq(401)
        expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.not_signed")])
      end
    end

    context "with a signature" do
      let!(:keypair) { OpenSSL::PKey::RSA.new(2048) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, public_key: keypair.public_key.to_pem) }
      let(:group) { Fabricate(:discourse_activity_pub_actor_group) }

      def build_headers(custom_object: nil, custom_actor: nil, custom_verb: nil, custom_path: nil, custom_key_id: nil, custom_keypair: true, custom_headers: {}, custom_params: {})
        _object = custom_object || object
        _actor = custom_actor || actor
        _headers = {
          "Host" => Discourse.current_hostname,
          "Date" => Time.now.utc.httpdate,
        }.merge(custom_headers)

        _headers["Signature"] = DiscourseActivityPub::Request.build_signature(
          verb: custom_verb || 'get',
          path: custom_path || Addressable::URI.parse(_object.ap_id).path,
          key_id: custom_key_id || signature_key_id(_actor),
          keypair: custom_keypair ? keypair : _actor.keypair,
          headers: _headers,
          custom_params: custom_params
        )

        _headers
      end

      context "with missing signature params" do
        let(:headers) { build_headers(custom_key_id: "") }

        it "returns the right unauthorized error" do
          get_object(object, headers: headers)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.missing_signature_params")])
        end
      end

      context "with an unsupported algorithm" do
        let(:headers) { build_headers(custom_params: { algorithm: "hmac-sha256" }) }

        it "returns the right unauthorized error" do
          get_object(object, headers: headers)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.unsupported_signature_algorithm")])
        end
      end

      context "with a rsa-sha256 algorithm" do
        let(:headers) { build_headers(custom_params: { algorithm: "rsa-sha256" }) }

        it "suceeds" do
          get_object(object, headers: headers)
          expect(response.status).to eq(200)
        end

        context "with an invalid date" do
          let(:headers) { build_headers(custom_params: { algorithm: "rsa-sha256" }, custom_headers: { "Date" => "not a date" }) }

          it "returns the right unauthorized error" do
            get_object(object, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.invalid_date_header", reason: "not RFC 2616 compliant date: \"not a date\"")])
          end
        end

        context "with a stale date" do
          let(:headers) { build_headers(custom_params: { algorithm: "rsa-sha256" }, custom_headers: { "Date" => 2.days.ago.utc.httpdate }) }

          it "returns the right unauthorized error" do
            get_object(object, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.stale_request")])
          end
        end
      end

      context "with a missing Signature pseudo-param" do
        let(:headers) { build_headers(custom_params: { "headers" => "(request-target) host" }) }

        it "returns the right unauthorized error" do
          get_object(object, headers: headers)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.date_must_be_signed")])
        end
      end

      context "with an invalid public key" do
        let(:headers) { build_headers }

        before do
          actor.public_key = "not a real key"
          actor.save!
        end

        it "attempts to refresh actor and returns the right error" do
          DiscourseActivityPubActor.any_instance.expects(:refresh_remote!).once.returns(nil)
          get_object(object, headers: headers)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.signature_verification_failed", id: actor.ap_id)])
        end

        it "succeeds if actor is refreshed with a valid public key" do
          actor_ap_json = actor.ap.json
          actor_ap_json["publicKey"] = {
            id: signature_key_id(actor),
            owner: actor.ap_id,
            publicKeyPem: keypair.public_key.to_pem
          }

          stub_request(:get, actor.ap_id)
            .to_return(body: actor_ap_json.to_json, headers: { "Content-Type" => "application/json" }, status: 200)

          get_object(object, headers: headers)
          expect(response.status).to eq(200)
        end

        it "fails with the right error if the actor is not refreshed with a valid public key" do
          stub_request(:get, actor.ap_id)
            .to_return(body: nil, status: 400)

          get_object(object, headers: headers)
          expect(response.status).to eq(401)
          expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.signature_verification_failed", id: actor.ap_id)])
        end
      end

      context "with a valid public key" do
        let(:headers) { build_headers }

        it "succeeds" do
          get_object(object, headers: headers)
          expect(response.status).to eq(200)
        end
      end

      context "with a new actor" do
        let(:new_actor) { build_actor_json(keypair.public_key.to_pem) }
        let(:headers) { build_headers(custom_key_id: new_actor[:publicKey][:id], custom_keypair: keypair) }

        before do
          stub_request(:get, new_actor[:id])
            .to_return(body: new_actor.to_json, headers: { "Content-Type" => "application/json" }, status: 200)
        end

        it "succeeds and creates the actor" do
          get_object(object, headers: headers)
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubActor.exists?(ap_id: new_actor[:id])).to eq(true)
        end
      end

      context "with a post request" do
        let(:body) { build_follow_json(group) }
        let(:invalid_digest) { Digest::SHA256.base64digest("invalid body") }
        let(:valid_digest) { Digest::SHA256.base64digest(body.to_json) }

        context "with an invalid digest" do
          let(:headers) {
            build_headers(custom_headers: {
              "Digest" => "SHA-256=#{invalid_digest}"
            })
          }

          it "returns the right unauthorized error" do
            post_to_inbox(group, body: body, headers: headers)
            expect(response.status).to eq(401)
            expect(response.parsed_body["errors"]).to eq([I18n.t("discourse_activity_pub.request.error.invalid_digest", { computed: valid_digest, digest: invalid_digest })])
          end
        end

        context "with a valid digest" do
          let(:headers) {
            build_headers(
              custom_headers: {
                "Digest" => "SHA-256=#{valid_digest}"
              },
              custom_verb: 'post',
              custom_path: Addressable::URI.parse(group.inbox).path
            )
          }

          before do
            toggle_activity_pub(group.model)
          end

          it "succeeds" do
            post_to_inbox(group, body: body, headers: headers)
            expect(response.status).to eq(202)
          end
        end
      end
    end
  end

  describe "#show" do
    it "returns a object json" do
      get_object(object)
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(object.ap.json)
    end
  end
end
