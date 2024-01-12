# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic, post_number: 1) }
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:activity_type) { DiscourseActivityPub::AP::Activity::Like.type }
  let!(:note) do
    Fabricate(:discourse_activity_pub_object_note, local: true, model: post, published_at: Time.now)
  end
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:json) { build_activity_json(object: note.ap.json, type: activity_type, actor: person) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Object }

  describe "#process" do
    before do
      stub_stored_request(note.attributed_to)
      toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
      topic.create_activity_pub_collection!
    end

    def perform_process(json, activity_type)
      klass = described_class.new
      klass.json = json
      klass.stubs(:type).returns(activity_type)
      klass.send(:process)
    end

    context "with a duplicate activity" do
      it "returns false" do
        expect(perform_process(json, activity_type)).to eq(true)
        expect(perform_process(json, activity_type)).to eq(false)
      end

      context "with verbose logging enabled" do
        before { setup_logging }
        after { teardown_logging }

        it "logs the right warning" do
          perform_process(json, activity_type)
          perform_process(json, activity_type)
          expect(@fake_logger.warnings.first).to eq(
            build_process_warning("activity_already_processed", json["id"]),
          )
        end
      end
    end

    context "when fails to create activity" do
      before do
        DiscourseActivityPubActivity
          .expects(:create!)
          .raises(ActiveRecord::RecordInvalid.new(DiscourseActivityPubActivity.new))
          .once
      end

      it "returns true" do
        expect(perform_process(json, activity_type)).to eq(true)
      end

      context "with verbose logging enabled" do
        before { setup_logging }
        after { teardown_logging }

        it "logs the right error" do
          perform_process(json, activity_type)
          expect(@fake_logger.errors.last).to match(
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_save_activity",
              activity_id: json[:id],
            ),
          )
        end
      end
    end
  end

  describe "#process_actor_and_object" do
    def perform_process(json, activity_type)
      klass = described_class.new
      klass.json = json
      klass.stubs(:type).returns(activity_type)
      klass.send(:process_actor_and_object)
    end

    context "with a valid activity" do
      before { stub_stored_request(note.attributed_to) }

      context "without activity pub enabled" do
        it "returns false" do
          expect(perform_process(json, activity_type)).to eq(false)
        end

        it "creates a actor" do
          perform_process(json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: json["actor"]["id"])).to eq(true)
        end

        it "creates an attributedTo actor" do
          perform_process(json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: json["object"]["attributedTo"])).to eq(
            true,
          )
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs a warning" do
            perform_process(json, activity_type)
            expect(@fake_logger.warnings.last).to match(
              build_process_warning("object_not_ready", json["id"]),
            )
          end
        end
      end

      context "with activity pub enabled" do
        before { toggle_activity_pub(actor.model) }

        it "returns true" do
          expect(perform_process(json, activity_type)).to eq(true)
        end

        it "creates a actor" do
          perform_process(json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: json["actor"]["id"])).to eq(true)
        end

        it "creates an attributedTo actor" do
          perform_process(json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: json["object"]["attributedTo"])).to eq(
            true,
          )
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "does not log a warning" do
            perform_process(json, activity_type)
            expect(@fake_logger.warnings.any?).to eq(false)
          end
        end

        context "with a local object uri" do
          let!(:json) do
            build_activity_json(object: note.ap.json["id"], type: activity_type, actor: person)
          end

          it "resolves the local object without a request" do
            expect_no_request
            expect(perform_process(json, activity_type)).to eq(true)
          end
        end
      end
    end

    context "with an invalid activity" do
      context "with an unspported actor" do
        before do
          @json = build_activity_json(object: actor, type: activity_type)
          @json["actor"]["type"] = "Service"
        end

        it "returns false" do
          expect(perform_process(@json, activity_type)).to eq(false)
        end

        it "does not create an actor" do
          perform_process(@json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json["actor"]["id"])).to eq(false)
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.first).to match(
              build_process_warning("object_not_supported", @json["actor"]["id"]),
            )
          end
        end
      end

      context "with an invalid object" do
        before { @json = build_activity_json }

        it "returns false" do
          expect(perform_process(@json, activity_type)).to eq(false)
        end

        it "creates an actor" do
          perform_process(@json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json["actor"]["id"])).to eq(true)
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.last).to match(
              build_process_warning("object_not_ready", @json["id"]),
            )
          end
        end
      end
    end
  end
end
