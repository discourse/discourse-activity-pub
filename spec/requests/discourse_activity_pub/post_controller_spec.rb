# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::PostController do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post1) { Fabricate(:post, topic: topic) }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.post.error.#{key}")] }
  end

  describe "#schedule" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        post "/ap/post/schedule/#{post1.id}"
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(build_error("not_enabled"))
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      context "with signed in staff" do
        let!(:user) { Fabricate(:user, moderator: true) }

        before { sign_in(user) }

        context "without a valid post id" do
          it "returns a post not found error" do
            post "/ap/post/schedule/#{post1.id + 1}"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("post_not_found"))
          end
        end

        context "with a valid post id" do
          context "with a first_post activity pub category" do
            before do
              toggle_activity_pub(category, callbacks: true, publication_type: "first_post")
            end

            context "with the first post" do
              before do
                post1.post_number = 1
                post1.save!
              end

              context "when the post is published" do
                before do
                  post1.custom_fields["activity_pub_published_at"] = Time.now
                  post1.save_custom_fields(true)
                end

                it "returns a can't schedule post error" do
                  post "/ap/post/schedule/#{post1.id}"
                  expect(response.status).to eq(422)
                  expect(response.parsed_body).to eq(build_error("cant_schedule_post"))
                end
              end

              context "when the post is scheduled" do
                before do
                  post1.custom_fields["activity_pub_scheduled_at"] = Time.now
                  post1.save_custom_fields(true)
                end

                it "returns a can't schedule post error" do
                  post "/ap/post/schedule/#{post1.id}"
                  expect(response.status).to eq(422)
                  expect(response.parsed_body).to eq(build_error("cant_schedule_post"))
                end
              end

              context "when the post is not scheduled or published" do
                it "schedules the post" do
                  Post.any_instance.expects(:activity_pub_schedule!)
                  post "/ap/post/schedule/#{post1.id}"
                end

                context "when scheduling succeeds" do
                  it "returns a success response" do
                    Post.any_instance.expects(:activity_pub_schedule!).returns(true)
                    post "/ap/post/schedule/#{post1.id}"
                    expect(response).to be_successful
                  end
                end

                context "when scheduling fails" do
                  it "returns a failed response" do
                    Post.any_instance.expects(:activity_pub_schedule!).returns(false)
                    post "/ap/post/schedule/#{post1.id}"
                    expect(response).not_to be_successful
                  end
                end
              end
            end

            context "with not the first post" do
              before do
                post1.post_number = 2
                post1.save!
              end

              it "returns a not first post error" do
                post "/ap/post/schedule/#{post1.id}"
                expect(response.status).to eq(422)
                expect(response.parsed_body).to eq(build_error("not_first_post"))
              end
            end
          end

          context "with a full_topic activity pub category" do
            before do
              toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
            end

            it "returns a first post not enabled error" do
              post "/ap/post/schedule/#{post1.id}"
              expect(response.status).to eq(403)
              expect(response.parsed_body).to eq(build_error("first_post_not_enabled"))
            end
          end
        end
      end

      context "without signed in staff" do
        let!(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an invalid access error" do
          post "/ap/post/schedule/#{post1.id}"
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "#unschedule" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        delete "/ap/post/schedule/#{post1.id}"
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(build_error("not_enabled"))
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      context "with signed in staff" do
        let!(:user) { Fabricate(:user, moderator: true) }

        before { sign_in(user) }

        context "without a valid post id" do
          it "returns a post not found error" do
            delete "/ap/post/schedule/#{post1.id + 1}"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("post_not_found"))
          end
        end

        context "with a valid post id" do
          context "with a first_post activity pub category" do
            before do
              toggle_activity_pub(category, callbacks: true, publication_type: "first_post")
            end

            context "with the first post" do
              before do
                post1.post_number = 1
                post1.save!
              end

              context "when the post is published" do
                before do
                  post1.custom_fields["activity_pub_published_at"] = Time.now
                  post1.save_custom_fields(true)
                end

                it "returns a can't unschedule post error" do
                  delete "/ap/post/schedule/#{post1.id}"
                  expect(response.status).to eq(422)
                  expect(response.parsed_body).to eq(build_error("cant_unschedule_post"))
                end
              end

              context "when the post is not scheduled" do
                it "returns a can't schedule post error" do
                  delete "/ap/post/schedule/#{post1.id}"
                  expect(response.status).to eq(422)
                  expect(response.parsed_body).to eq(build_error("cant_unschedule_post"))
                end
              end

              context "when the post is scheduled and not published" do
                before do
                  post1.custom_fields["activity_pub_scheduled_at"] = Time.now
                  post1.save_custom_fields(true)
                end

                it "unschedules the post" do
                  Post.any_instance.expects(:activity_pub_unschedule!)
                  delete "/ap/post/schedule/#{post1.id}"
                end

                context "when unscheduling succeeds" do
                  it "returns a success response" do
                    Post.any_instance.expects(:activity_pub_unschedule!).returns(true)
                    delete "/ap/post/schedule/#{post1.id}"
                    expect(response).to be_successful
                  end
                end

                context "when unscheduling fails" do
                  it "returns a failed response" do
                    Post.any_instance.expects(:activity_pub_unschedule!).returns(false)
                    delete "/ap/post/schedule/#{post1.id}"
                    expect(response).not_to be_successful
                  end
                end
              end
            end

            context "with not the first post" do
              before do
                post1.post_number = 2
                post1.save!
              end

              it "returns a not first post error" do
                delete "/ap/post/schedule/#{post1.id}"
                expect(response.status).to eq(422)
                expect(response.parsed_body).to eq(build_error("not_first_post"))
              end
            end
          end

          context "with a full_topic activity pub category" do
            before do
              toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
              topic.create_activity_pub_collection!
            end

            it "returns a first post not enabled error" do
              delete "/ap/post/schedule/#{post1.id}"
              expect(response.status).to eq(403)
              expect(response.parsed_body).to eq(build_error("first_post_not_enabled"))
            end
          end
        end
      end

      context "without signed in staff" do
        let!(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "returns an invalid access error" do
          post "/ap/post/schedule/#{post1.id}"
          expect(response.status).to eq(403)
        end
      end
    end
  end
end
