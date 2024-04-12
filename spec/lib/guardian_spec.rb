# frozen_string_literal: true
RSpec.describe Guardian do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:another_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: user, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }

  describe "can_edit?" do
    describe "a Post" do
      context "with activity pub enabled" do
        before { toggle_activity_pub(category) }

        context "with a remote Note" do
          fab!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: false) }

          it "returns false for all users" do
            expect(Guardian.new(admin).can_edit?(post)).to be_falsey
            expect(Guardian.new(user).can_edit?(post)).to be_falsey
            expect(Guardian.new(another_user).can_edit?(post)).to be_falsey
          end
        end

        context "with a local Note" do
          fab!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: true) }

          it "returns true for the right users" do
            expect(Guardian.new(admin).can_edit?(post)).to be_truthy
            expect(Guardian.new(user).can_edit?(post)).to be_truthy
            expect(Guardian.new(another_user).can_edit?(post)).to be_falsey
          end
        end

        context "without a Note" do
          it "returns true for the right users" do
            expect(Guardian.new(admin).can_edit?(post)).to be_truthy
            expect(Guardian.new(user).can_edit?(post)).to be_truthy
            expect(Guardian.new(another_user).can_edit?(post)).to be_falsey
          end
        end
      end

      context "with activity pub disabled" do
        it "returns true for the right users" do
          expect(Guardian.new(admin).can_edit?(post)).to be_truthy
          expect(Guardian.new(user).can_edit?(post)).to be_truthy
          expect(Guardian.new(another_user).can_edit?(post)).to be_falsey
        end
      end
    end
  end

  describe "can_change_post_owner?" do
    describe "a Post" do
      context "with a change owner request" do
        let!(:request) do
          env =
            create_request_env(path: "/t/#{topic.id}/change-owner").merge(
              {
                "REQUEST_METHOD" => "POST",
                "action_dispatch.request.parameters" => {
                  "post_ids" => [post.id.to_s],
                  "username" => another_user.username,
                  "controller" => "topics",
                  "action" => "change_post_owners",
                  "topic_id" => topic.id.to_s,
                },
              },
            )
          ActionDispatch::Request.new(env)
        end

        context "with activity pub enabled" do
          before { toggle_activity_pub(category) }

          it "returns false for all users" do
            expect(Guardian.new(admin, request).can_change_post_owner?).to be_falsey
            expect(Guardian.new(user, request).can_change_post_owner?).to be_falsey
            expect(Guardian.new(another_user, request).can_change_post_owner?).to be_falsey
          end
        end

        context "with activity pub disabled" do
          it "returns true for the right users" do
            expect(Guardian.new(admin, request).can_change_post_owner?).to be_truthy
            expect(Guardian.new(user, request).can_change_post_owner?).to be_falsey
            expect(Guardian.new(another_user, request).can_change_post_owner?).to be_falsey
          end
        end
      end
    end
  end
end
