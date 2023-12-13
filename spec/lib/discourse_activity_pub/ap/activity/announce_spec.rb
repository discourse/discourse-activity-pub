# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Announce do
  let!(:category) { Fabricate(:category) }
  let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe '#process' do
    let!(:followed_actor_id) { "https://mastodon.pavilion.tech/groups/1" }
    let!(:followed_actor) {
      Fabricate(:discourse_activity_pub_actor_group,
        ap_id: followed_actor_id,
        local: false
      )
    }
    let!(:create_json) {
      build_activity_json(
        type: "Create",
        to: [category_actor.ap_id]
      )
    }
    let!(:announce_json) { 
      build_activity_json(
        id: "#{followed_actor_id}#note/1",
        type: 'Announce',
        actor: followed_actor,
        object: create_json,
        to: [category_actor.ap_id]
      )
    }

    context 'with activity pub enabled' do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
      end

      context "when addressed publicly" do
        before do
          announce_json[:cc] = DiscourseActivityPub::JsonLd.public_collection_id
        end

        context "when announcing an activity" do
          it 'does not create an announce activity' do
            perform_process(announce_json)
            expect(
              DiscourseActivityPubActivity.exists?(
                ap_type: described_class.type,
                actor_id: followed_actor.id
              )
            ).to eq(false)
          end
    
          it "processes the announced activity" do
            DiscourseActivityPub::AP::Activity::Create.any_instance.expects(:process).once
            perform_process(announce_json)
          end
        end

        context "when announcing an object" do
          let!(:note_actor_id) { "https://mastodon.discourse.com/users/1" }
          let!(:note_actor) {
            Fabricate(:discourse_activity_pub_actor_person,
              ap_id: note_actor_id,
              local: false
            )
          }
          let!(:followed_actor_id) { "https://mastodon.discourse.com/users/2" }
          let!(:followed_actor) {
            Fabricate(:discourse_activity_pub_actor_person,
              ap_id: followed_actor_id,
              local: false
            )
          }
          let!(:follow) {
            Fabricate(:discourse_activity_pub_follow,
              follower: category.activity_pub_actor,
              followed: followed_actor
            )
          }
          let!(:object_json) {
            build_object_json(
              attributed_to: note_actor_id,
              name: "My cool topic title"
            )
          }
          let(:announce_json) { 
            build_activity_json(
              id: "#{followed_actor_id}#note/1",
              type: 'Announce',
              actor: followed_actor,
              object: object_json,
              to: [category_actor.ap_id]
            )
          }

          before do
            stub_stored_request(note_actor)
            perform_process(announce_json, category.activity_pub_actor.ap_id)
          end

          it 'creates an announce activity' do
            expect(
              DiscourseActivityPubActivity.exists?(
                ap_type: described_class.type,
                actor_id: followed_actor.id
              )
            ).to eq(true)
          end

          it "performs the announce activity as a create activity" do
            post = Post.find_by(raw: object_json[:content])
            expect(post.present?).to be(true)
            expect(post.topic.present?).to be(true)
            expect(post.topic.title).to eq(object_json[:name])
            expect(post.post_number).to be(1)
          end
        end
      end

      context "when not addressed publicly" do
        before do  
          SiteSetting.activity_pub_verbose_logging = true
          @orig_logger = Rails.logger
          Rails.logger = @fake_logger = FakeLogger.new
        end
  
        after do
          Rails.logger = @orig_logger
          SiteSetting.activity_pub_verbose_logging = false
        end

        it 'does not create the announce activity' do
          perform_process(announce_json)
          expect(
            DiscourseActivityPubActivity.exists?(
              ap_type: described_class.type,
              actor_id: followed_actor.id
            )
          ).to eq(false)
        end
  
        it "does not process the announced activity" do
          DiscourseActivityPub::AP::Activity::Create.any_instance.expects(:process).never
          perform_process(announce_json)
        end

        it "logs a warning" do
          perform_process(announce_json)
          expect(@fake_logger.warnings.first).to match(
            I18n.t('discourse_activity_pub.process.warning.announce_not_publicly_addressed')
          )
        end
      end
    end
  end
end
