# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActor do
  let!(:category) { Fabricate(:category) }

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: category.id,
            model_type: category.class.name,
            username: category.slug,
            ap_id: "foo",
            domain: "domain.com",
            ap_type: DiscourseActivityPub::AP::Actor::Person.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      before do
        @actor = described_class.create!(
          local: true,
          model_id: category.id,
          model_type: category.class.name,
          username: category.slug,
          ap_id: "foo",
          domain: "domain.com",
          ap_type: DiscourseActivityPub::AP::Actor::Group.type
        )
      end

      it "creates an actor" do
        expect(@actor.errors.any?).to eq(false)
        expect(@actor.persisted?).to eq(true)
      end

      it "sets inboxes and outboxes for the actor" do
        expect(@actor.inbox).to eq("#{@actor.ap_id}/inbox")
        expect(@actor.outbox).to eq("#{@actor.ap_id}/outbox")
      end
    end

    context "with no username" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: category.id,
            model_type: category.class.name,
            ap_type: DiscourseActivityPub::AP::Actor::Person.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a username" do
      it "creates an actor " do
        actor = described_class.create!(
          local: true,
          model_id: category.id,
          model_type: category.class.name,
          ap_id: "foo",
          ap_type: DiscourseActivityPub::AP::Actor::Group.type,
          username: category.slug
        )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
    end

    context "with a remote actor with the same username" do
      let!(:username) { "angus" }
      let!(:user) { Fabricate(:user, username: username) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, username: username, local: false) }

      it "creates an actor" do
        actor = described_class.create!(
          local: true,
          model_id: user.id,
          model_type: user.class.name,
          ap_type: DiscourseActivityPub::AP::Actor::Person.type,
          username: user.username
        )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
    end

    context "with a local actor with the same username" do
      let!(:username) { "angus" }
      let!(:user) { Fabricate(:user, username: username) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, username: username, local: true) }

      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: user.id,
            model_type: user.class.name,
            ap_type: DiscourseActivityPub::AP::Actor::Person.type,
            username: user.username
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#ensure_for" do
    let(:category) { Fabricate(:category) }

    context "without activty pub enabled on the object" do
      it "does not create an actor" do
        described_class.ensure_for(category)
        expect(category.activity_pub_actor.present?).to eq(false)
      end
    end

    context "with activity pub enabled on the object" do
      before do
        toggle_activity_pub(category)
      end

      it "ensures a valid actor exists" do
        described_class.ensure_for(category.reload)
        expect(category.activity_pub_actor.present?).to eq(true)
        expect(category.activity_pub_actor.ap_type).to eq('Group')
      end

      it "publishes activity pub state" do
        message = MessageBus.track_publish("/activity-pub") do
          described_class.ensure_for(category.reload)
        end.first
        expect(message.data).to eq(
          { model: { id: category.id, type: "category", ready: true, enabled: true } }
        )
      end

      it "does not duplicate actors" do
        described_class.ensure_for(category.reload)
        described_class.ensure_for(category)
        expect(DiscourseActivityPubActor.where(model_id: category.id).size).to eq(1)
      end
    end
  end

  describe "#find_by_handle" do
    context "with a stored local actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: true) }

      context "when local param is true" do
        it "returns the stored actor" do
          expect(DiscourseActivityPubActor.find_by_handle(actor.handle, local: true)).to eq(actor)
        end
      end

      context "when local param is false" do
        it "does not return the stored actor" do
          expect(DiscourseActivityPubActor.find_by_handle(actor.handle, local: false)).to eq(nil)
        end
      end
    end

    context "with a stored remote actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: false) }

      context "when local param is true" do
        it "does not return the stored actor" do
          expect(DiscourseActivityPubActor.find_by_handle(actor.handle, local: true)).to eq(nil)
        end
      end

      context "when local param is false" do
        it "returns the stored actor" do
          expect(DiscourseActivityPubActor.find_by_handle(actor.handle, local: false)).to eq(actor)
        end

        context "when refresh param is true" do
          it "calls resolve_and_store with the handle" do
            DiscourseActivityPubActor.expects(:resolve_and_store).with(actor.handle).once
            DiscourseActivityPubActor.find_by_handle(actor.handle, local: false, refresh: true)
          end
        end
      end
    end

    context "without a stored actor" do
      let!(:handle) { "username@external.com" }

      context "when local param is true" do
        it "does not call resolve_and_store" do
          DiscourseActivityPubActor.expects(:resolve_and_store).never
          DiscourseActivityPubActor.find_by_handle(handle, local: true)
        end
      end

      context "when local param is false" do
        it "calls resolve_and_store with the handle" do
          DiscourseActivityPubActor.expects(:resolve_and_store).with(handle).once
          DiscourseActivityPubActor.find_by_handle(handle, local: false)
        end
      end
    end
  end

  describe "#resolve_and_store" do
    let!(:actor) { build_actor_json }
    let!(:handle) { "#{actor[:preferredUsername]}@external.com" }

    context "when handle cant be webfingered" do
      before do
        DiscourseActivityPub::Webfinger.expects(:find_id_by_handle).with(handle).returns(nil)
      end

      it "returns nil" do
        expect(DiscourseActivityPubActor.resolve_and_store(handle)).to eq(nil)
      end
    end

    context "when handle can be webfingered" do
      before do
        DiscourseActivityPub::Webfinger.expects(:find_id_by_handle).with(handle).returns(actor[:id])
        DiscourseActivityPub::JsonLd.expects(:resolve_object).with(actor[:id]).returns(actor)
      end

      it "stores and returns the actor" do
        expect(
          DiscourseActivityPubActor.resolve_and_store(handle)
        ).to eq(
          DiscourseActivityPubActor.find_by(ap_id: actor[:id])
        )
      end
    end
  end
end