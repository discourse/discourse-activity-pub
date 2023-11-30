# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::WebfingerController do
  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.webfinger.error.#{key}")] }
  end

  describe "#index" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        get "/.well-known/webfinger"
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(build_error("not_enabled"))
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      context "with login required" do
        before { SiteSetting.login_required = true }

        it "returns a not enabled error" do
          get "/.well-known/webfinger"
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(build_error("not_enabled"))
        end
      end

      context "with an unsupported scheme" do
        it "returns a not supported error" do
          get "/.well-known/webfinger?resource=https://forum.com/user/1"
          expect(response.status).to eq(405)
          expect(response.parsed_body).to eq(build_error("resource_not_supported"))
        end
      end

      context "with a supported scheme" do
        let(:actor) { Fabricate(:discourse_activity_pub_actor_group, domain: nil) }

        context "when the domain is incorrect" do
          it "returns a not found error" do
            get "/.well-known/webfinger?resource=acct:#{actor.username}@anotherforum.com"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("resource_not_found"))
          end
        end

        context "when the username is incorrect" do
          it "returns a not found error" do
            get "/.well-known/webfinger?resource=acct:angus@#{DiscourseActivityPub.host}"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("resource_not_found"))
          end
        end

        context "when the username and domain are correct" do
          it "returns the resource" do
            get "/.well-known/webfinger?resource=acct:#{actor.username}@#{DiscourseActivityPub.host}"
            expect(response.status).to eq(200)

            body = JSON.parse(response.body)
            expect(body["subject"]).to eq("acct:#{actor.username}@#{DiscourseActivityPub.host}")
            expect(body["aliases"]).to eq(actor.webfinger_aliases)
            expect(body["links"]).to eq(actor.webfinger_links.map(&:as_json))
          end
        end
      end
    end
  end
end
