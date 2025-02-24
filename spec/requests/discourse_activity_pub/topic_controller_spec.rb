# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::TopicController do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.topic.error.#{key}")] }
  end

  before { Jobs.run_immediately! }

  describe "#publish" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        post "/ap/topic/publish/#{topic.id}"
        expect(response.status).to eq(404)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      context "with signed in staff" do
        let!(:user) { Fabricate(:user, moderator: true) }

        before { sign_in(user) }

        context "without a valid topic id" do
          it "returns a topic not found error" do
            post "/ap/topic/publish/#{topic.id + 1}"
            expect(response.status).to eq(400)
            expect(response.parsed_body).to eq(build_error("topic_not_found"))
          end
        end

        context "with a valid topic id" do
          context "with a first_post activity pub category" do
            before { toggle_activity_pub(category, publication_type: "first_post") }

            it "publishes the topic" do
              post "/ap/topic/publish/#{topic.id}"
              expect(response.status).to eq(422)
              expect(response.parsed_body).to eq(build_error("cant_publish_topic"))
            end
          end

          context "with a full_topic activity pub category" do
            before { toggle_activity_pub(category, publication_type: "full_topic") }

            it "publishes all the posts in the topic" do
              post "/ap/topic/publish/#{topic.id}"
              expect(response.status).to eq(200)
              expect(post1.reload.activity_pub_published?).to eq(true)
              expect(post2.reload.activity_pub_published?).to eq(true)
            end

            context "when first post is scheduled" do
              before do
                post1.custom_fields["activity_pub_scheduled_at"] = Time.now
                post1.save_custom_fields(true)
              end

              it "returns a can't publish topic error" do
                post "/ap/topic/publish/#{topic.id}"
                expect(response.status).to eq(422)
                expect(response.parsed_body).to eq(build_error("cant_publish_topic"))
              end
            end

            context "when all posts are published" do
              before do
                post1.custom_fields["activity_pub_published_at"] = Time.now
                post1.save_custom_fields(true)
                post2.custom_fields["activity_pub_published_at"] = Time.now
                post2.save_custom_fields(true)
              end

              it "returns a can't publish topic error" do
                post "/ap/topic/publish/#{topic.id}"
                expect(response.status).to eq(422)
                expect(response.parsed_body).to eq(build_error("cant_publish_topic"))
              end
            end
          end
        end
      end
    end
  end
end
