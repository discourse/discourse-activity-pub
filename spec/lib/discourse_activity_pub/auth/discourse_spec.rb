# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::Discourse do
  let!(:domain1) { "external.com" }
  let!(:redirect_uri) do
    "#{DiscourseActivityPub.base_url}/#{DiscourseActivityPub::Auth::Discourse::REDIRECT_PATH}"
  end
  let!(:keypair) { OpenSSL::PKey::RSA.new(2048) }
  let!(:public_key) { keypair.public_key.to_pem }
  let!(:private_key) { keypair.to_pem }
  let!(:client_request_body) do
    {
      public_key: public_key,
      client_id: DiscourseActivityPubActor.application.ap_id,
      application_name: SiteSetting.title,
      auth_redirect: redirect_uri,
      scopes: DiscourseActivityPubClient::DISCOURSE_SCOPE,
    }
  end

  def build_response(body: {}, status: 200)
    Excon::Response.new(body: body.to_json, status: status)
  end

  def expect_request(domain: "", path: "", body: nil, verb: :post, response: nil, headers: nil)
    opts = {}
    opts[:body] = body.to_json if body
    opts[:headers] = {}
    opts[:headers]["Content-Type"] = "application/json" if body
    headers.each { |k, v| opts[:headers][k] = v } if headers

    Excon.expects(:send).with(verb, "https://#{domain}/#{path}", opts).returns(response)
  end

  describe "create_client" do
    def perform(domain)
      auth = DiscourseActivityPub::Auth::Discourse.new(domain: domain1)
      auth.keypair = keypair
      auth.create_client
    end

    it "sends the right request to register a client" do
      expect_request(
        domain: domain1,
        path: DiscourseActivityPub::Auth::Discourse::CLIENT_PATH,
        body: client_request_body,
      )
      perform(domain1)
    end

    context "with a successful client response" do
      before do
        expect_request(
          domain: domain1,
          path: DiscourseActivityPub::Auth::Discourse::CLIENT_PATH,
          body: client_request_body,
          response: build_response(body: { success: "OK" }, status: 200),
        )
      end

      it "saves the client" do
        perform(domain1)
        client =
          DiscourseActivityPubClient.find_by(
            auth_type: DiscourseActivityPubClient.auth_types[:discourse],
            domain: domain1,
          )
        expect(client).to be_present
        expect(client.credentials["public_key"]).to eq(public_key)
        expect(client.credentials["private_key"]).to eq(private_key)
      end

      it "returns the client" do
        expect(perform(domain1)).to be_an_instance_of(DiscourseActivityPubClient)
      end
    end

    context "with an unsuccessful client response" do
      before do
        expect_request(
          domain: domain1,
          path: DiscourseActivityPub::Auth::Discourse::CLIENT_PATH,
          body: client_request_body,
          response: build_response(body: { failed: "FAILED" }, status: 422),
        )
      end

      it "does not save a client" do
        expect { perform(domain1) }.not_to change { DiscourseActivityPubClient.count }
      end

      it "returns nil" do
        expect(perform(domain1)).to eq(nil)
      end
    end
  end
end
