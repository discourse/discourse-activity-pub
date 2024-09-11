# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ContextResolver do
  describe "#perform" do
    context "with an object not in reply to" do
      let!(:object) { Fabricate(:discourse_activity_pub_object_note, model: nil) }

      it "does not make requests" do
        expect_no_request
        described_class.perform(object)
      end

      it "succeeds" do
        resolver = described_class.new(object)
        resolver.perform
        expect(resolver.success?).to be_truthy
      end
    end

    context "with a local object within the reply depth limit" do
      let!(:local_object) { Fabricate(:discourse_activity_pub_object_note) }
      let!(:reply_to_2_actor_json) { build_actor_json }
      let!(:reply_to_2_json) do
        build_object_json(
          in_reply_to: local_object.ap_id,
          attributed_to: reply_to_2_actor_json[:id],
        )
      end
      let!(:reply_to_1_actor_json) { build_actor_json }
      let!(:reply_to_1_json) do
        build_object_json(
          in_reply_to: reply_to_2_json[:id],
          attributed_to: reply_to_1_actor_json[:id],
        )
      end
      let!(:object) do
        Fabricate(
          :discourse_activity_pub_object_note,
          reply_to_id: reply_to_1_json[:id],
          model: nil,
        )
      end

      context "when the remote objects successfully resolve" do
        before do
          stub_object_request(reply_to_1_actor_json)
          stub_object_request(reply_to_1_json)
          stub_object_request(reply_to_2_actor_json)
          stub_object_request(reply_to_2_json)
        end

        context "when the local object is in a full_topic topic" do
          let!(:category) { Fabricate(:category) }
          let!(:topic) { Fabricate(:topic, category: category) }
          let!(:post) { Fabricate(:post, topic: topic) }

          before do
            local_object.update(model_id: post.id, model_type: "Post")
            toggle_activity_pub(category, publication_type: "full_topic")
            topic.create_activity_pub_collection!
          end

          it "resolves and stores the remote objects" do
            described_class.perform(object)
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_1_actor_json[:id]).exists?,
            ).to be_truthy
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_2_actor_json[:id]).exists?,
            ).to be_truthy
            expect(
              DiscourseActivityPubObject.where(
                ap_id: reply_to_1_json[:id],
                reply_to_id: reply_to_2_json[:id],
              ).exists?,
            ).to be_truthy
            expect(
              DiscourseActivityPubObject.where(
                ap_id: reply_to_2_json[:id],
                reply_to_id: local_object.ap_id,
              ).exists?,
            ).to be_truthy
          end

          it "creates users and posts for the actors and objects in the reply chain" do
            described_class.perform(object)
            user1 = DiscourseActivityPubActor.find_by(ap_id: reply_to_1_actor_json[:id])&.model
            user2 = DiscourseActivityPubActor.find_by(ap_id: reply_to_2_actor_json[:id])&.model
            expect(user1.present?).to be_truthy
            expect(user2.present?).to be_truthy
            expect(
              Post.where(raw: reply_to_1_json[:content], user_id: user1.id).exists?,
            ).to be_truthy
            expect(
              Post.where(raw: reply_to_2_json[:content], user_id: user2.id).exists?,
            ).to be_truthy
          end

          it "succeeds" do
            resolver = described_class.new(object)
            resolver.perform
            expect(resolver.success?).to be_truthy
          end
        end

        context "when the local object is not in a full_topic topic" do
          let!(:category) { Fabricate(:category) }
          let!(:topic) { Fabricate(:topic, category: category) }
          let!(:post) { Fabricate(:post, topic: topic) }

          before do
            local_object.update(model_id: post.id, model_type: "Post")
            toggle_activity_pub(category, publication_type: "first_post")
          end

          it "does not store the remote objects" do
            described_class.perform(object)
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_1_actor_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_2_actor_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubObject.where(ap_id: reply_to_1_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubObject.where(ap_id: reply_to_2_json[:id]).exists?,
            ).to be_falsey
          end

          it "does not create users and posts for the actors and objects in the reply chain" do
            described_class.perform(object)
            user1 = DiscourseActivityPubActor.find_by(ap_id: reply_to_1_actor_json[:id])&.model
            user2 = DiscourseActivityPubActor.find_by(ap_id: reply_to_2_actor_json[:id])&.model
            expect(user1.present?).to be_falsey
            expect(user2.present?).to be_falsey
            expect(Post.where(raw: reply_to_1_json[:content]).exists?).to be_falsey
            expect(Post.where(raw: reply_to_2_json[:content]).exists?).to be_falsey
          end

          it "does not succeed" do
            resolver = described_class.new(object)
            resolver.perform
            expect(resolver.success?).to be_falsey
          end
        end
      end

      context "when some remote objects don't successfully resolve" do
        before do
          stub_object_request(reply_to_1_actor_json, status: 404, body: {}.to_json)
          stub_object_request(reply_to_1_json)
          stub_object_request(reply_to_2_actor_json)
          stub_object_request(reply_to_2_json)
        end

        context "when the local object is in a full_topic topic" do
          let!(:category) { Fabricate(:category) }
          let!(:topic) { Fabricate(:topic, category: category) }
          let!(:post) { Fabricate(:post, topic: topic) }

          before do
            local_object.update(model_id: post.id, model_type: "Post")
            toggle_activity_pub(category, publication_type: "full_topic")
            topic.create_activity_pub_collection!
          end

          it "does not store the remote objects" do
            described_class.perform(object)
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_1_actor_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubActor.where(ap_id: reply_to_2_actor_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubObject.where(ap_id: reply_to_1_json[:id]).exists?,
            ).to be_falsey
            expect(
              DiscourseActivityPubObject.where(ap_id: reply_to_2_json[:id]).exists?,
            ).to be_falsey
          end

          it "does not create users and posts for the actors and objects in the reply chain" do
            described_class.perform(object)
            user1 = DiscourseActivityPubActor.find_by(ap_id: reply_to_1_actor_json[:id])&.model
            user2 = DiscourseActivityPubActor.find_by(ap_id: reply_to_2_actor_json[:id])&.model
            expect(user1.present?).to be_falsey
            expect(user2.present?).to be_falsey
            expect(Post.where(raw: reply_to_1_json[:content]).exists?).to be_falsey
            expect(Post.where(raw: reply_to_2_json[:content]).exists?).to be_falsey
          end

          it "does not succeed" do
            resolver = described_class.new(object)
            resolver.perform
            expect(resolver.success?).to be_falsey
          end
        end
      end
    end

    context "with a local object not within the reply depth limit" do
      let!(:local_object) { Fabricate(:discourse_activity_pub_object_note) }

      let!(:reply_to_4_actor_json) { build_actor_json }
      let!(:reply_to_4_json) do
        build_object_json(
          in_reply_to: local_object.ap_id,
          attributed_to: reply_to_3_actor_json[:id],
        )
      end
      let!(:reply_to_3_actor_json) { build_actor_json }
      let!(:reply_to_3_json) do
        build_object_json(
          in_reply_to: reply_to_4_json[:id],
          attributed_to: reply_to_3_actor_json[:id],
        )
      end
      let!(:reply_to_2_actor_json) { build_actor_json }
      let!(:reply_to_2_json) do
        build_object_json(
          in_reply_to: reply_to_3_json[:id],
          attributed_to: reply_to_2_actor_json[:id],
        )
      end
      let!(:reply_to_1_actor_json) { build_actor_json }
      let!(:reply_to_1_json) do
        build_object_json(
          in_reply_to: reply_to_2_json[:id],
          attributed_to: reply_to_1_actor_json[:id],
        )
      end
      let!(:object) do
        Fabricate(
          :discourse_activity_pub_object_note,
          reply_to_id: reply_to_1_json[:id],
          model: nil,
        )
      end

      before do
        stub_object_request(reply_to_1_actor_json)
        stub_object_request(reply_to_1_json)
        stub_object_request(reply_to_2_actor_json)
        stub_object_request(reply_to_2_json)
        stub_object_request(reply_to_3_actor_json)
        stub_object_request(reply_to_3_json)
        stub_object_request(reply_to_4_actor_json)
        stub_object_request(reply_to_4_json)
      end

      it "does not store the remote objects" do
        described_class.perform(object)
        expect(
          DiscourseActivityPubActor.where(ap_id: reply_to_1_actor_json[:id]).exists?,
        ).to be_falsey
        expect(
          DiscourseActivityPubActor.where(ap_id: reply_to_2_actor_json[:id]).exists?,
        ).to be_falsey
        expect(
          DiscourseActivityPubActor.where(ap_id: reply_to_3_actor_json[:id]).exists?,
        ).to be_falsey
        expect(
          DiscourseActivityPubActor.where(ap_id: reply_to_4_actor_json[:id]).exists?,
        ).to be_falsey
        expect(DiscourseActivityPubObject.where(ap_id: reply_to_1_json[:id]).exists?).to be_falsey
        expect(DiscourseActivityPubObject.where(ap_id: reply_to_2_json[:id]).exists?).to be_falsey
        expect(DiscourseActivityPubObject.where(ap_id: reply_to_3_json[:id]).exists?).to be_falsey
        expect(DiscourseActivityPubObject.where(ap_id: reply_to_4_json[:id]).exists?).to be_falsey
      end

      it "does not succeed" do
        resolver = described_class.new(object)
        resolver.perform
        expect(resolver.success?).to be_falsey
      end
    end
  end
end
