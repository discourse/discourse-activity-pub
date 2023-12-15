# frozen_string_literal: true

RSpec.describe Jobs::DiscourseActivityPubDeliver do
  let!(:category) { Fabricate(:category) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_accept, actor: group) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }

  def build_job_args(args = {})
    {
      object_id: args.key?(:object_id) ? args[:object_id] : activity.id,
      object_type: args.key?(:object_type) ? args[:object_type] : "DiscourseActivityPubActivity",
      from_actor_id: args.key?(:from_actor_id) ? args[:from_actor_id] : group.id,
      send_to: args.key?(:send_to) ? args[:send_to] : person.inbox,
      retry_count: args.key?(:retry_count) ? args[:retry_count] : nil,
    }
  end

  def execute_job(args = {})
    described_class.new.execute(build_job_args(args))
  end

  context "without activity pub enabled" do
    before { SiteSetting.activity_pub_enabled = false }

    it "does not perform a request" do
      expect_no_request
      execute_job
    end
  end

  context "with site activity pub enabled" do
    before { SiteSetting.activity_pub_enabled = true }

    context "with login required" do
      before { SiteSetting.login_required = true }

      it "does not perform a request" do
        expect_no_request
        execute_job
      end
    end
  end

  context "with model activity pub disabled" do
    before { toggle_activity_pub(category, disable: true) }

    it "does not perform a request" do
      expect_no_request
      execute_job
    end
  end

  context "with model activity pub enabled" do
    before do
      toggle_activity_pub(category, callbacks: true)
      freeze_time
    end

    after { unfreeze_time }

    context "without required arguments" do
      it "does not perform a request" do
        expect_no_request
        execute_job(object_id: nil)
        execute_job(from_actor_id: nil)
        execute_job(send_to: nil)
      end
    end

    context "with invalid arguments" do
      it "does not perform a request" do
        expect_no_request
        execute_job(object_id: activity.id + 20)
        execute_job(from_actor_id: activity.actor.id + 20)
      end
    end

    it "initializes the right request" do
      expect_request(body: published_json(activity), actor_id: group.id, uri: person.inbox)
      execute_job
    end

    it "performs the right request" do
      expect_post
      execute_job
    end

    context "when request succeeds" do
      before { expect_post(returns: true) }

      it "does not retry" do
        expect_not_enqueued_with(job: :discourse_activity_pub_deliver) { execute_job }
      end
    end

    context "when request fails" do
      before { expect_post(returns: false) }

      it "enqueues retries" do
        freeze_time

        retry_count = described_class::MAX_RETRY_COUNT - 1
        delay = described_class::RETRY_BACKOFF * retry_count
        next_job_args = build_job_args(retry_count: retry_count + 1)

        expect_enqueued_with(
          job: :discourse_activity_pub_deliver,
          args: next_job_args,
          at: delay.minutes.from_now,
        ) { execute_job(retry_count: retry_count) }
      end

      it "does not retry more than the maximum retry count" do
        expect_not_enqueued_with(job: :discourse_activity_pub_deliver) do
          execute_job(retry_count: described_class::MAX_RETRY_COUNT)
        end
      end
    end

    context "with a ready object" do
      let!(:topic) { Fabricate(:topic, category: group.model) }
      let!(:post) { Fabricate(:post, topic: topic) }
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, local: true, model: post) }

      context "when delivering a Create" do
        let!(:activity) do
          Fabricate(:discourse_activity_pub_activity_create, object: note, actor: group)
        end

        it "performs the right request" do
          expect_request(body: published_json(activity), actor_id: group.id, uri: person.inbox)
          execute_job(object_id: activity.id, from_actor_id: activity.actor.id)
        end

        context "when associated post is trashed prior to delivery" do
          before { activity.object.model.trash! }

          it "does not perform a request" do
            expect_no_request
            execute_job(object_id: activity.id, from_actor_id: activity.actor.id)
          end
        end
      end

      context "when delivering a Delete" do
        let!(:activity) do
          Fabricate(:discourse_activity_pub_activity_delete, object: note, actor: group)
        end

        it "performs the right request" do
          expect_request(body: published_json(activity), actor_id: group.id, uri: person.inbox)
          execute_job(object_id: activity.id, from_actor_id: activity.actor.id)
        end

        context "when associated post is restored prior to delivery" do
          before { activity.object.model.recover! }

          it "does not perform a request" do
            expect_no_request
            execute_job(object_id: activity.id, from_actor_id: activity.actor.id)
          end
        end
      end

      context "when delivering an Update" do
        let!(:activity) do
          Fabricate(:discourse_activity_pub_activity_update, object: note, actor: group)
        end

        it "performs the right request" do
          expect_request(body: published_json(activity), actor_id: group.id, uri: person.inbox)
          execute_job(object_id: activity.id, from_actor_id: activity.actor.id)
        end
      end

      context "when delivery actor and activity actor are different" do
        let!(:activity) do
          Fabricate(:discourse_activity_pub_activity_create, object: note, actor: person)
        end

        def find_announce
          DiscourseActivityPubActivity.find_by(
            local: true,
            actor_id: group.id,
            object_id: activity.id,
            object_type: activity.class.name,
            ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
            visibility: DiscourseActivityPubActivity.visibilities[:public],
          )
        end

        it "wraps the activity in an announce" do
          expect_request(actor_id: group.id, uri: person.inbox)
          execute_job(object_id: activity.id, from_actor_id: group.id)
          expect(find_announce.present?).to eq(true)
        end

        it "delivers the announce activity" do
          expect_request(body_type: "Announce", actor_id: group.id, uri: person.inbox)
          execute_job(object_id: activity.id, from_actor_id: group.id)
        end

        context "when activities are in a collection" do
          let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }

          before do
            note.collection_id = collection.id
            note.save!
          end

          it "wraps the activities in announcements" do
            expect_request(actor_id: group.id, uri: person.inbox)
            execute_job(
              object_id: collection.id,
              object_type: "DiscourseActivityPubCollection",
              from_actor_id: group.id,
            )
            expect(
              DiscourseActivityPubActivity.exists?(
                local: true,
                actor_id: group.id,
                object_id: activity.id,
                object_type: activity.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
                visibility: DiscourseActivityPubActivity.visibilities[:public],
              ),
            ).to eq(true)
          end

          it "delivers the collection" do
            expect_request(body_type: "OrderedCollection", actor_id: group.id, uri: person.inbox)
            execute_job(
              object_id: collection.id,
              object_type: "DiscourseActivityPubCollection",
              from_actor_id: group.id,
            )
          end
        end
      end
    end
  end
end
