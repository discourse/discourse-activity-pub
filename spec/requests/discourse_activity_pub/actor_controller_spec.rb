# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ActorController do
  let!(:actor1) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:actor2) { Fabricate(:discourse_activity_pub_actor_group, local: false, model: nil) }
  let!(:follower1) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "google.com",
      username: "bob_ap",
      model: Fabricate(:user, username: "bob_local"),
    )
  end
  let!(:follow1) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower1,
      followed: actor1,
      created_at: (DateTime.now - 2),
    )
  end
  let!(:follower2) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "twitter.com",
      username: "jenny_ap",
      model: nil,
    )
  end
  let!(:follow2) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower2,
      followed: actor1,
      created_at: (DateTime.now - 1),
    )
  end
  let!(:follower3) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "netflix.com",
      username: "xavier_ap",
      model: Fabricate(:user, username: "xavier_local"),
    )
  end
  let!(:follow3) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower3,
      followed: actor1,
      created_at: DateTime.now,
    )
  end

  describe "#followers" do
    context "with a user" do
      let!(:user) { Fabricate(:user) }

      before { sign_in(user) }

      context "with activity pub enabled" do
        before { toggle_activity_pub(actor1.model) }

        it "returns the actors followers" do
          get "/ap/local/actor/#{actor1.id}/followers.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].map { |f| f["url"] }).to eq(
            [follower3.ap_id, follower2.ap_id, follower1.ap_id],
          )
        end

        it "returns followers without users" do
          get "/ap/local/actor/#{actor1.id}/followers.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].map { |f| f["username"] }).to include("jenny_ap")
        end

        it "orders by user" do
          get "/ap/local/actor/#{actor1.id}/followers.json?order=user"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].map { |f| f.dig("model", "username") }).to eq(
            ["xavier_local", "bob_local", nil],
          )
        end

        it "orders by actor" do
          get "/ap/local/actor/#{actor1.id}/followers.json?order=actor"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].map { |f| f["username"] }).to eq(
            %w[xavier_ap jenny_ap bob_ap],
          )
        end

        it "paginates" do
          get "/ap/local/actor/#{actor1.id}/followers.json?limit=2&page=1"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].map { |f| f["url"] }).to eq([follower1.ap_id])
        end

        context "with publishing disabled" do
          before { SiteSetting.login_required = true }

          it "returns the right error" do
            get "/ap/local/actor/#{actor1.id}/followers.json"
            expect_not_enabled(response)
          end
        end
      end
    end
  end

  describe "#follow" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(actor1.model) }

      context "with a normal user" do
        let(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an unauthorized error" do
          post "/ap/local/actor/#{actor1.id}/follow"
          expect(response.status).to eq(403)
        end
      end

      context "with an admin user" do
        let(:admin) { Fabricate(:user, admin: true) }

        before { sign_in(admin) }

        context "with an invalid actor id" do
          it "returns a not found error" do
            post "/ap/local/actor/#{actor1.id + 50}/follow", params: { target_actor_id: actor2.id }
            expect(response.status).to eq(404)
          end
        end

        context "with a valid actor id" do
          context "with an invalid follow actor id" do
            it "returns a not found error" do
              post "/ap/local/actor/#{actor1.id}/follow",
                   params: {
                     target_actor_id: actor2.id + 50,
                   }
              expect(response.status).to eq(404)
            end
          end

          context "with a valid target actor id" do
            context "with an actor that can follow other actors" do
              it "initiates a follow" do
                DiscourseActivityPub::FollowHandler.expects(:follow).with(actor1.id, actor2.id)
                post "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
              end

              it "returns a success when follow is enqueued" do
                DiscourseActivityPub::FollowHandler
                  .expects(:follow)
                  .with(actor1.id, actor2.id)
                  .returns(true)
                post "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["success"]).to eq("OK")
              end

              it "returns a failure when follow is not enqueued" do
                DiscourseActivityPub::FollowHandler
                  .expects(:follow)
                  .with(actor1.id, actor2.id)
                  .returns(false)
                post "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["failed"]).to eq("FAILED")
              end
            end
          end
        end
      end
    end
  end

  describe "#unfollow" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(actor1.model) }

      context "with a normal user" do
        let(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an unauthorized error" do
          delete "/ap/local/actor/#{actor1.id}/follow"
          expect(response.status).to eq(403)
        end
      end

      context "with an admin user" do
        let(:admin) { Fabricate(:user, admin: true) }

        before { sign_in(admin) }

        context "with an invalid actor id" do
          it "returns a not found error" do
            delete "/ap/local/actor/#{actor1.id + 50}/follow",
                   params: {
                     target_actor_id: actor2.id,
                   }
            expect(response.status).to eq(404)
          end
        end

        context "with a valid actor id" do
          context "with an invalid target actor id" do
            it "returns a not found error" do
              delete "/ap/local/actor/#{actor1.id}/follow",
                     params: {
                       target_actor_id: actor2.id + 50,
                     }
              expect(response.status).to eq(404)
            end
          end

          context "with a valid target actor id" do
            context "with an actor that is not following the target actor" do
              it "returns a not found error" do
                delete "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(404)
              end
            end

            context "with an actor that is following the target actor" do
              let!(:follow) do
                Fabricate(:discourse_activity_pub_follow, follower: actor1, followed: actor2)
              end

              it "initiates an unfollow" do
                DiscourseActivityPub::FollowHandler.expects(:unfollow).with(actor1.id, actor2.id)
                delete "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
              end

              it "returns a success when unfollow is successful" do
                DiscourseActivityPub::FollowHandler
                  .expects(:unfollow)
                  .with(actor1.id, actor2.id)
                  .returns(true)
                delete "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["success"]).to eq("OK")
              end

              it "returns a failure when unfollow is not successful" do
                DiscourseActivityPub::FollowHandler
                  .expects(:unfollow)
                  .with(actor1.id, actor2.id)
                  .returns(false)
                delete "/ap/local/actor/#{actor1.id}/follow", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["failed"]).to eq("FAILED")
              end
            end
          end
        end
      end
    end
  end

  describe "#reject" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(actor1.model) }

      context "with a normal user" do
        let(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an unauthorized error" do
          post "/ap/actor/#{actor1.id}/reject"
          expect(response.status).to eq(403)
        end
      end

      context "with an admin user" do
        let(:admin) { Fabricate(:user, admin: true) }

        before { sign_in(admin) }

        context "with an invalid actor id" do
          it "returns a not found error" do
            post "/ap/actor/#{actor1.id + 50}/reject", params: { target_actor_id: actor2.id }
            expect(response.status).to eq(404)
          end
        end

        context "with a valid actor id" do
          context "with an invalid target actor id" do
            it "returns a not found error" do
              post "/ap/actor/#{actor1.id}/reject", params: { target_actor_id: actor2.id + 50 }
              expect(response.status).to eq(404)
            end
          end

          context "with a valid target actor id" do
            context "with a target actor that is not following the actor" do
              it "returns a not found error" do
                post "/ap/actor/#{actor1.id}/reject", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(404)
              end
            end

            context "with a target actor that is following the actor" do
              let!(:follow) do
                Fabricate(:discourse_activity_pub_follow, follower: actor2, followed: actor1)
              end

              it "initiates a reject" do
                DiscourseActivityPub::FollowHandler.expects(:reject).with(actor1.id, actor2.id)
                post "/ap/actor/#{actor1.id}/reject", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
              end

              it "returns a success when reject is successful" do
                DiscourseActivityPub::FollowHandler
                  .expects(:reject)
                  .with(actor1.id, actor2.id)
                  .returns(true)
                post "/ap/actor/#{actor1.id}/reject", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["success"]).to eq("OK")
              end

              it "returns a failure when reject is not successful" do
                DiscourseActivityPub::FollowHandler
                  .expects(:reject)
                  .with(actor1.id, actor2.id)
                  .returns(false)
                post "/ap/actor/#{actor1.id}/reject", params: { target_actor_id: actor2.id }
                expect(response.status).to eq(200)
                expect(response.parsed_body["failed"]).to eq("FAILED")
              end
            end
          end
        end
      end
    end
  end

  describe "#find_by_handle" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(actor1.model) }

      context "with a normal user" do
        let(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an unauthorized error" do
          get "/ap/local/actor/#{actor1.id}/find-by-handle"
          expect(response.status).to eq(403)
        end
      end

      context "with an admin user" do
        let(:admin) { Fabricate(:user, admin: true) }

        before { sign_in(admin) }

        context "with an invalid actor id" do
          it "returns a not found error" do
            get "/ap/local/actor/#{actor1.id + 50}/find-by-handle",
                params: {
                  handle: actor2.handle,
                }
            expect(response.status).to eq(404)
          end
        end

        context "with a valid actor id" do
          context "when the actor cant be found" do
            let!(:handle) { "wrong@handle.com" }

            it "returns failed json" do
              DiscourseActivityPubActor.expects(:find_by_handle).with(handle).returns(nil)
              get "/ap/local/actor/#{actor1.id}/find-by-handle", params: { handle: handle }
              expect(response.status).to eq(200)
              expect(response.parsed_body["failed"]).to eq("FAILED")
            end
          end

          context "when the actor can be found" do
            let!(:handle) { actor2.handle }

            it "returns the actor" do
              DiscourseActivityPubActor.expects(:find_by_handle).with(handle).returns(actor2)
              get "/ap/local/actor/#{actor1.id}/find-by-handle", params: { handle: actor2.handle }
              expect(response.status).to eq(200)
              expect(response.parsed_body["actor"]["id"]).to eq(actor2.id)
            end
          end
        end
      end
    end
  end
end
