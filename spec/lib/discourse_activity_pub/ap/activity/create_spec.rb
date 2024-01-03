# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Create do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity::Compose }

  describe '#process' do
    before do
      toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
      topic.create_activity_pub_collection!
      DiscourseActivityPub::DeliveryHandler.stubs(:perform).returns(true)
    end

    context "with Note inReplyTo to a Note" do
      let!(:original_object) { Fabricate(:discourse_activity_pub_object_note, model: post) }
      let(:reply_external_url) { "https://external.com/object/note/#{SecureRandom.hex(8)}" }
      let(:reply_json) {
        build_activity_json(
          actor: person,
          object: build_object_json(
            in_reply_to: original_object.ap_id,
            url: reply_external_url,
            attributed_to: original_object.attributed_to
          ),
          type: 'Create',
          to: [category.activity_pub_actor.ap_id]
        )
      }

      before do
        freeze_time
        stub_stored_request(original_object.attributed_to)
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
            actor_id: person.id
          ).size
        ).to be(1)
      end

      it "creates a single object" do
        expect(
          DiscourseActivityPubObject.where(
            ap_type: "Note",
            model_id: Post.find_by(raw: reply_json[:object][:content]).id,
            model_type: "Post",
            domain: "external.com"
          ).size
        ).to be(1)
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
          type: 'Create',
          to: [category.activity_pub_actor.ap_id]
        )
      }

      before do
        SiteSetting.activity_pub_verbose_logging = true
        original_object.model.trash!
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
          I18n.t('discourse_activity_pub.process.warning.cannot_reply_to_deleted_post')
        )
      end
    end

    context "with a Note not inReplyTo another Note" do
      let!(:delivered_to) { category.activity_pub_actor.ap_id }
      let!(:object_json) {
        build_object_json(
          name: "My cool topic title",
          attributed_to: person
        )
      }
      let!(:new_post_json) {
        build_activity_json(
          actor: person,
          object: object_json,
          type: 'Create'
        )
      }

      before do
        stub_stored_request(person)
      end

      shared_examples "creates a new topic" do
        it "creates a new topic" do
          perform_process(new_post_json, delivered_to)
          post = Post.find_by(raw: object_json[:content])
          expect(post.present?).to be(true)
          expect(post.topic.present?).to be(true)
          expect(post.topic.title).to eq(object_json[:name])
          expect(post.post_number).to be(1)
        end

        it "creates a note" do
          perform_process(new_post_json, delivered_to)
          post = Post.find_by(raw: object_json[:content])
          expect(
            DiscourseActivityPubObject.exists?(
              ap_type: "Note",
              model_id: post.id,
              model_type: "Post",
              attributed_to_id: person.ap_id
            )
          ).to eq(true)
        end

        it "creates an activity" do
          perform_process(new_post_json, delivered_to)
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_id: new_post_json[:id],
              ap_type: "Create",
              actor_id: person.id
            )
          ).to be(true)
        end
      end

      context "when the target is following the create actor" do
        before do
          Fabricate(:discourse_activity_pub_follow,
            follower: category.activity_pub_actor,
            followed: person
          )
        end

        include_examples "creates a new topic"

        context "when the category has first_post enabled" do
          before do
            category.custom_fields['activity_pub_publication_type'] = 'first_post'
            category.save_custom_fields(true)
          end

          include_examples "creates a new topic"
        end
      end

      context "when the target is following the parent actor" do
        let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
        let!(:announce_json) { 
          build_activity_json(
            type: 'Announce',
            actor: group,
            object: new_post_json,
            to: [category.activity_pub_actor.ap_id],
            cc: [DiscourseActivityPub::JsonLd.public_collection_id]
          )
        }
        before do
          Fabricate(:discourse_activity_pub_follow,
            follower: category.activity_pub_actor,
            followed: group
          )
          klass = DiscourseActivityPub::AP::Activity::Announce.new
          klass.json = announce_json
          klass.delivered_to << delivered_to
          klass.process
        end
  
        include_examples "creates a new topic"
      end

      context "when the target is not following the create actor" do
        before do
          SiteSetting.activity_pub_verbose_logging = true
          @orig_logger = Rails.logger
          Rails.logger = @fake_logger = FakeLogger.new
          perform_process(new_post_json, delivered_to)
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
  
        it "does not create a note" do
          expect(
            DiscourseActivityPubObject.exists?(
              ap_type: "Note",
              attributed_to_id: person.ap_id
            )
          ).to eq(true)
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
            I18n.t('discourse_activity_pub.process.warning.only_followed_actors_create_new_topics')
          )
        end
      end
    end
  end
end
