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

      context "with an unsupported scheme" do
        it "returns a not supported error" do
          get "/.well-known/webfinger?resource=https://forum.com/user/1"
          expect(response.status).to eq(405)
          expect(response.parsed_body).to eq(build_error("resource_not_supported"))
        end
      end

      context "with a supported scheme" do
        let!(:group) { Fabricate(:discourse_activity_pub_actor_group, domain: nil) }
        let!(:person) { Fabricate(:discourse_activity_pub_actor_person, domain: nil) }

        context "when the domain is incorrect" do
          it "returns a not found error" do
            get "/.well-known/webfinger?resource=acct:#{group.username}@anotherforum.com"
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
            get "/.well-known/webfinger?resource=acct:#{group.username}@#{DiscourseActivityPub.host}"
            expect(response.status).to eq(200)

            body = JSON.parse(response.body)
            expect(body["subject"]).to eq("acct:#{group.username}@#{DiscourseActivityPub.host}")
            expect(body["aliases"]).to eq(group.webfinger_aliases)
            expect(body["links"]).to eq(group.webfinger_links.map(&:as_json))
          end
        end

        context "with login required" do
          before { SiteSetting.login_required = true }

          it "returns permitted resource types" do
            get "/.well-known/webfinger?resource=acct:#{group.username}@#{DiscourseActivityPub.host}"
            expect(response.status).to eq(200)

            body = JSON.parse(response.body)
            expect(body["subject"]).to eq("acct:#{group.username}@#{DiscourseActivityPub.host}")
            expect(body["aliases"]).to eq(group.webfinger_aliases)
            expect(body["links"]).to eq(group.webfinger_links.map(&:as_json))
          end

          it "does not return unpermitted resource types" do
            get "/.well-known/webfinger?resource=acct:#{person.username}@#{DiscourseActivityPub.host}"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("resource_not_found"))
          end
        end
      end
    end
  end
end
