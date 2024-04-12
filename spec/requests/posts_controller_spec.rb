# frozen_string_literal: true

RSpec.describe PostsController do
  describe "#create" do
    describe "when logged in" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
      before { sign_in(user) }

      context "with a ready ActivityPub category" do
        fab!(:category)

        before { toggle_activity_pub(category) }

        context "when passed activity_pub_visibility params" do
          let!(:params) do
            {
              raw: "This is my note",
              title: "This is my title",
              activity_pub_visibility: "public",
              category: category.id,
            }
          end

          it "saves the default visibility" do
            post "/posts.json", params: params
            expect(response.status).to eq(200)
            expect(response.parsed_body["activity_pub_visibility"]).to eq(
              DiscourseActivityPubActivity.default_visibility,
            )
          end

          context "when the category has a default visibility" do
            before do
              category.activity_pub_actor.default_visibility = "first_post"
              category.activity_pub_actor.save!
            end

            it "saves the category's default visibility" do
              post "/posts.json", params: params
              expect(response.status).to eq(200)
              expect(response.parsed_body["activity_pub_visibility"]).to eq(
                category.activity_pub_default_visibility,
              )
            end
          end
        end
      end
    end
  end
end
