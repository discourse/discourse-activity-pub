# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Create do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity::Compose }

  describe "#process" do
    before do
      toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
      topic.create_activity_pub_collection!
    end

    context "with Note inReplyTo to a Note" do
      let!(:original_object) { Fabricate(:discourse_activity_pub_object_note, model: post) }
      let(:reply_external_url) { "https://external.com/object/note/#{SecureRandom.hex(8)}" }
      let(:reply_json) do
        build_activity_json(
          actor: person,
          object: build_object_json(in_reply_to: original_object.ap_id, url: reply_external_url),
          type: "Create",
        )
      end

      before do
        freeze_time
        perform_process(reply_json)
      end

      it "creates a post with the right fields" do
        reply = Post.find_by(raw: reply_json[:object][:content])
        expect(reply.present?).to be(true)
        expect(reply.reply_to_post_number).to eq(post.post_number)
        expect(reply.activity_pub_published_at.to_datetime.to_i).to eq_time(Time.now.utc.to_i)
        expect(reply.activity_pub_url).to eq(reply_external_url)
      end

      it "creates a single activity" do
        expect(
          DiscourseActivityPubActivity.where(
            ap_id: reply_json[:id],
            ap_type: "Create",
            actor_id: person.id,
          ).size,
        ).to be(1)
      end

      it "creates a single object" do
        expect(
          DiscourseActivityPubObject.where(
            ap_type: "Note",
            model_id: Post.find_by(raw: reply_json[:object][:content]).id,
            model_type: "Post",
            domain: "external.com",
          ).size,
        ).to be(1)
      end
    end

    context "with a Note inReplyTo a Note associated with a deleted Post" do
      let!(:original_object) { Fabricate(:discourse_activity_pub_object_note) }
      let(:reply_json) do
        build_activity_json(
          actor: person,
          object: build_object_json(in_reply_to: original_object.ap_id),
          type: "Create",
        )
      end

      before do
        SiteSetting.activity_pub_verbose_logging = true
        original_object.model.destroy!
        @orig_logger = Rails.logger
        Rails.logger = @fake_logger = FakeLogger.new
        perform_process(reply_json)
      end

      after do
        Rails.logger = @orig_logger
        SiteSetting.activity_pub_verbose_logging = false
      end

      it "does not create a post" do
        expect(Post.exists?(raw: reply_json[:object][:content])).to be(false)
      end

      it "does not create an activity" do
        expect(
          DiscourseActivityPubActivity.exists?(
            ap_id: reply_json[:id],
            ap_type: "Create",
            actor_id: person.id,
          ),
        ).to be(false)
      end

      it "logs a warning" do
        expect(@fake_logger.warnings.last).to match(
          I18n.t("discourse_activity_pub.process.warning.not_a_reply"),
        )
      end
    end

    context "with a Note not inReplyTo another Note" do
      let(:new_post_json) do
        build_activity_json(actor: person, object: build_object_json, type: "Create")
      end

      before do
        SiteSetting.activity_pub_verbose_logging = true
        @orig_logger = Rails.logger
        Rails.logger = @fake_logger = FakeLogger.new
        perform_process(new_post_json)
      end

      after do
        Rails.logger = @orig_logger
        SiteSetting.activity_pub_verbose_logging = false
      end

      it "does not create a post" do
        expect(Post.exists?(raw: new_post_json[:object][:content])).to be(false)
      end

      it "does not create an activity" do
        expect(
          DiscourseActivityPubActivity.exists?(
            ap_id: new_post_json[:id],
            ap_type: "Create",
            actor_id: person.id,
          ),
        ).to be(false)
      end

      it "logs a warning" do
        expect(@fake_logger.warnings.last).to match(
          I18n.t("discourse_activity_pub.process.warning.not_a_reply"),
        )
      end
    end
  end
end
