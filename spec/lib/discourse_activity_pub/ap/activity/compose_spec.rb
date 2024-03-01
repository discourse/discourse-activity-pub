# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Compose do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe "#process" do
    let!(:object_json) { build_object_json }
    let!(:activity_json) do
      build_activity_json(
        object: object_json,
        type: "Update",
        to: [category.activity_pub_actor.ap_id],
      )
    end
    let!(:note) do
      Fabricate(
        :discourse_activity_pub_object_note,
        ap_id: object_json[:id],
        local: false,
        model: post,
      )
    end

    def process_json(json)
      # Compose is a pseudo parent so we use a real activity, Update, to test.
      klass = DiscourseActivityPub::AP::Activity::Update.new
      klass.json = json
      klass.process
    end

    context "with full topic enabled" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
        topic.create_activity_pub_collection!
      end

      it "works" do
        process_json(activity_json)
        expect(post.reload.raw).to eq(object_json[:content])
      end

      context "with an activity and object from different hosts" do
        before do
          setup_logging

          @mismatched_json = activity_json.dup
          @mismatched_json[
            :id
          ] = "https://other-external.com/activity/update/#{SecureRandom.hex(8)}"

          process_json(@mismatched_json)
        end

        after { teardown_logging }

        it "does not perform the activity" do
          expect(post.reload.raw).not_to eq(object_json[:content])
        end

        it "does not create an activity" do
          expect(DiscourseActivityPubActivity.exists?(ap_id: @mismatched_json[:id])).to be(false)
        end

        it "logs a warning" do
          expect(@fake_logger.warnings.first).to match(
            I18n.t("discourse_activity_pub.process.warning.activity_host_must_match_object_host"),
          )
        end
      end
    end

    context "with full topic disabled" do
      before do
        setup_logging
        toggle_activity_pub(category, callbacks: true, publication_type: "first_post")
        process_json(activity_json)
      end
      after { teardown_logging }

      it "doesn't work" do
        expect(post.reload.raw).not_to eq(object_json[:content])
      end

      it "logs a warning" do
        expect(@fake_logger.warnings.first).to match(
          I18n.t("discourse_activity_pub.process.warning.full_topic_not_enabled"),
        )
      end
    end
  end
end
