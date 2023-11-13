# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::CategoryController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:follower1) {
    Fabricate(:discourse_activity_pub_actor_person,
      domain: 'google.com',
      username: 'bob_ap',
      model: Fabricate(:user,
        username: 'bob_local'
      )
    )
  }
  let!(:follow1) {
    Fabricate(:discourse_activity_pub_follow,
      follower: follower1,
      followed: actor,
      created_at: (DateTime.now - 2)
    )
  }
  let!(:follower2) {
    Fabricate(:discourse_activity_pub_actor_person,
      domain: 'twitter.com',
      username: 'jenny_ap',
      model: nil
    )
  }
  let!(:follow2) {
    Fabricate(:discourse_activity_pub_follow,
      follower: follower2,
      followed: actor,
      created_at: (DateTime.now - 1)
    )
  }
  let!(:follower3) {
    Fabricate(:discourse_activity_pub_actor_person,
      domain: 'netflix.com',
      username: 'xavier_ap',
      model: Fabricate(:user,
        username: 'xavier_local'
      )
    )
  }
  let!(:follow3) {
    Fabricate(:discourse_activity_pub_follow,
      follower: follower3,
      followed: actor,
      created_at: DateTime.now
    )
  }

  describe "#follow" do
    context "with activity pub enabled" do
      before do
        toggle_activity_pub(actor.model)
      end

      context "without a user who can edit the category" do
        let(:user) { Fabricate(:user) }

        before do
          sign_in(user)
        end

        it "returns an unauthorized error" do
          post "/ap/category/#{actor.model.id}/follow"
          expect(response.status).to eq(403)
        end
      end

      context "with a user who can edit the category" do
        let(:admin) { Fabricate(:user, admin: true) }

        before do
          sign_in(admin)
        end

        context "without a handle" do
          it "returns a bad request error" do
            post "/ap/category/#{actor.model.id}/follow"
            expect(response.status).to eq(400)
          end
        end

        context "with a handle" do
          let(:handle) { "actor@external.com" }

          it "initiates a follow" do
            DiscourseActivityPub::FollowHandler.expects(:perform).with(actor, handle)
            post "/ap/category/#{actor.model.id}/follow", params: { handle: handle }
            expect(response.status).to eq(200)
          end

          it "returns a success when follow is enqueued" do
            DiscourseActivityPub::FollowHandler.expects(:perform).with(actor, handle).returns(true)
            post "/ap/category/#{actor.model.id}/follow", params: { handle: handle }
            expect(response.status).to eq(200)
            expect(response.parsed_body['success']).to eq('OK')
          end

          it "returns a failure when follow is not enqueued" do
            DiscourseActivityPub::FollowHandler.expects(:perform).with(actor, handle).returns(false)
            post "/ap/category/#{actor.model.id}/follow", params: { handle: handle }
            expect(response.status).to eq(200)
            expect(response.parsed_body['failed']).to eq('FAILED')
          end
        end
      end
    end
  end 

  describe "#followers" do
    context "with activity pub enabled" do
      before do
        toggle_activity_pub(actor.model)
      end

      it "returns the categories followers" do
        get "/ap/category/#{actor.model.id}/followers.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body['followers'].map{|f| f["url"] }).to eq(
          [follower3.ap_id, follower2.ap_id, follower1.ap_id]
        )
      end

      it "returns followers without users" do
        get "/ap/category/#{actor.model.id}/followers.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body['followers'].map{|f| f["username"] }).to include("jenny_ap")
      end

      it "orders by user" do
        get "/ap/category/#{actor.model.id}/followers.json?order=user"
        expect(response.status).to eq(200)
        expect(response.parsed_body['followers'].map{|f| f.dig("user","username") }).to eq(
          ["xavier_local", "bob_local", nil]
        )
      end

      it "orders by actor" do
        get "/ap/category/#{actor.model.id}/followers.json?order=actor"
        expect(response.status).to eq(200)
        expect(response.parsed_body['followers'].map{|f| f["username"] }).to eq(
          ["xavier_ap", "jenny_ap", "bob_ap"]
        )
      end

      it "paginates" do
        get "/ap/category/#{actor.model.id}/followers.json?limit=2&page=1"
        expect(response.status).to eq(200)
        expect(response.parsed_body['followers'].map{|f| f["url"] }).to eq(
          [follower1.ap_id]
        )
      end
    end
  end
end