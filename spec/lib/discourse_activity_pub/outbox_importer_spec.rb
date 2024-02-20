# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::OutboxImporter do
  let!(:category) { Fabricate(:category) }
  let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:person2_json) { build_actor_json }
  let!(:object1_json) { build_object_json(name: "My cool title", attributed_to: target_actor) }
  let!(:object2_json) { build_object_json(in_reply_to: object1_json[:id], attributed_to: person2_json[:id]) }
  let!(:create_1_json) { build_activity_json(actor: target_actor, object: object1_json, type: "Create") }
  let!(:create_2_json) { build_activity_json(actor: person2_json[:id], object: object2_json, type: "Create") }
  let!(:ordered_collection_json) do
    build_collection_json(
      type: "OrderedCollection",
      items: [
        create_1_json,
        create_2_json
      ]
    )
  end

  describe "#perform" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

    def build_warning_log(key)
      message = I18n.t(
        "discourse_activity_pub.import.warning.import_did_not_start",
        actor_id: actor.ap_id,
        target_actor_id: target_actor.ap_id
      )
      message += ": " + I18n.t(
        "discourse_activity_pub.import.warning.#{key}",
        actor_id: actor.ap_id,
        target_actor_id: target_actor.ap_id
      )
      prefix_log(message)
    end

    context "when the actor is ready" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
      end

      context "when not following the target actor" do
        before { setup_logging }
        after { teardown_logging }

        it "does not perform any requests" do
          described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          DiscourseActivityPub::Request
            .expects(:get_json_ld)
            .never
        end

        it "logs the right warning" do
          described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          expect(@fake_logger.warnings.first).to eq(build_warning_log("not_following_target"))
        end
      end

      context "when following the target actor" do
        let!(:follow1) do
          Fabricate(:discourse_activity_pub_follow, follower: actor, followed: target_actor)
        end

        context "when target actor does not return an outbox collection" do
          before { setup_logging }
          after { teardown_logging }
  
          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(nil)
          end

          it "does not process any activities" do
            DiscourseActivityPub::AP::Activity
              .expects(:process)
              .never
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          end
  
          it "logs the right warning" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(@fake_logger.warnings.first).to eq(build_warning_log("failed_to_retrieve_outbox"))
          end
        end

        context "when target actor returns an invalid outbox collection" do
          let!(:collection_json) {
            build_collection_json(
              type: "Collection",
              items: [
                create_1_json,
                create_2_json
              ]
            )
          }        

          before do
            setup_logging
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(collection_json)
          end
  
          after { teardown_logging }
  
          it "does not process any activities" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          end
  
          it "logs the right warning" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(@fake_logger.warnings.first).to eq(build_warning_log("outbox_response_invalid"))
          end
        end

        context "when target actor returns a valid outbox collection" do
          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.ap_id)
              .returns(target_actor.ap.json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .twice
          end

          it "creates the right topic" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(category.topics.first.title).to eq(object1_json[:name])
          end

          it "creates the right posts" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            posts = category.topics.first.posts
            expect(posts.first.raw).to eq(object1_json[:content])
            expect(posts.second.raw).to eq(object2_json[:content])
          end

          it "creates the right actors" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id]))
          end

          it "creates the right activities" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(
              DiscourseActivityPubActor.exists?(
                ap_id: [
                  create_1_json[:id],
                  create_2_json[:id]
                ]
              )
            )
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }
    
            it "logs the right info" do
              described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
              expect(@fake_logger.info.first).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_started",
                    actor_id: actor.ap_id,
                    target_actor_id: target_actor.ap_id
                  )
                )
              )
            end
          end
        end
      end
    end
  end
end
