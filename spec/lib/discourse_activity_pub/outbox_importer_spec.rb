# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::OutboxImporter do
  let!(:person1) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:person2_json) { build_actor_json }
  let!(:object1_json) { build_object_json(name: "My cool title", attributed_to: person1) }
  let!(:object2_json) { build_object_json(in_reply_to: object1_json[:id], attributed_to: person2_json[:id]) }
  let!(:create_1_json) { build_activity_json(actor: person1, object: object1_json, type: "Create") }
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

    context "with a category actor following a remote actor" do
      let!(:category) { Fabricate(:category) }
      let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
      let!(:follow1) do
        Fabricate(:discourse_activity_pub_follow, follower: category_actor, followed: person1)
      end

      context "with full_topic enabled" do
        before do
          toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
        end

        context "with new activities" do
          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person1.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person1.ap_id)
              .returns(person1.ap.json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .twice
          end

          it "creates the right topic" do
            described_class.perform(actor_id: category_actor.id, target_actor_id: person1.id)
            expect(category.topics.first.title).to eq(object1_json[:name])
          end

          it "creates the right posts" do
            described_class.perform(actor_id: category_actor.id, target_actor_id: person1.id)
            posts = category.topics.first.posts
            expect(posts.first.raw).to eq(object1_json[:content])
            expect(posts.second.raw).to eq(object2_json[:content])
          end

          it "creates the right actors" do
            described_class.perform(actor_id: category_actor.id, target_actor_id: person1.id)
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id]))
          end

          it "creates the right activities" do
            described_class.perform(actor_id: category_actor.id, target_actor_id: person1.id)
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
              described_class.perform(actor_id: category_actor.id, target_actor_id: person1.id)
              expect(@fake_logger.info.first).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_started",
                    actor_id: category_actor.ap_id,
                    target_actor_id: person1.ap_id
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
