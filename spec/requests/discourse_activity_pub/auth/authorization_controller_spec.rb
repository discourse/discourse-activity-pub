# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::AuthorizationController do
  let!(:user) { Fabricate(:user) }

  before { sign_in(user) }

  it { expect(described_class).to be < DiscourseActivityPub::AuthController }

  describe "#destroy" do
    context "without an actor id" do
      it "raises a bad request error" do
        delete "/ap/auth/authorization"
        expect(response.status).to eq(400)
      end
    end

    context "with an actor id" do
      let!(:domain) { "https://external1.com" }
      let!(:actor_id) { "https://external1.com/users/user1" }

      context "when the user has authorized the actor" do
        before { user.activity_pub_save_actor_id(domain, actor_id) }

        it "removes the actor id" do
          delete "/ap/auth/authorization", params: { actor_id: actor_id }
          expect(user.reload.activity_pub_actor_ids[actor_id]).to eq(nil)
        end

        it "is successful" do
          delete "/ap/auth/authorization", params: { actor_id: actor_id }
          expect(response).to be_successful
        end
      end

      context "when user has not authorized the actor" do
        it "is not successful" do
          delete "/ap/auth/authorization", params: { actor_id: actor_id }
          expect(response).not_to be_successful
        end
      end
    end
  end
end
