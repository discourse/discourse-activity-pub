# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Create do
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe '#process' do

    def perform_process(json)
      klass = described_class.new
      klass.json = json
      klass.process
    end

    context 'with activity pub enabled' do
      before do
        toggle_activity_pub(group.model, callbacks: true)
      end

      context "with Note inReplyTo to a Note" do
        let!(:original_object) { Fabricate(:discourse_activity_pub_object_note) }
        let(:reply_json) {
          build_activity_json(
            actor: person,
            object: build_object_json(
              in_reply_to: original_object.ap_id
            ),
            type: 'Create'
          )
        }

        before do
          perform_process(reply_json)
        end

        it "creates a post" do
          expect(
            Post.exists?(raw: reply_json[:object][:content])
          ).to be(true)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: reply_json[:id],
              ap_type: "Create",
              actor_id: person.id
            )
          ).to be(true)
        end
      end

      context "with a Note inReplyTo a Note associated with a deleted Post" do
        let!(:original_object) { Fabricate(:discourse_activity_pub_object_note) }
        let(:reply_json) {
          build_activity_json(
            actor: person,
            object: build_object_json(
              in_reply_to: original_object.ap_id
            ),
            type: 'Create'
          )
        }

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
          expect(
            Post.exists?(raw: reply_json[:object][:content])
          ).to be(false)
        end

        it "does not create an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: reply_json[:id],
              ap_type: "Create",
              actor_id: person.id
            )
          ).to be(false)
        end

        it "logs a warning" do
          expect(@fake_logger.warnings.last).to match(
            I18n.t('discourse_activity_pub.process.warning.not_a_reply')
          )
        end
      end

      context "with a Note not inReplyTo another Note" do
        let(:new_post_json) {
          build_activity_json(
            actor: person,
            object: build_object_json,
            type: 'Create'
          )
        }

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
          expect(
            Post.exists?(raw: new_post_json[:object][:content])
          ).to be(false)
        end

        it "does not create an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: new_post_json[:id],
              ap_type: "Create",
              actor_id: person.id
            )
          ).to be(false)
        end

        it "logs a warning" do
          expect(@fake_logger.warnings.last).to match(
            I18n.t('discourse_activity_pub.process.warning.not_a_reply')
          )
        end
      end
    end
  end
end
