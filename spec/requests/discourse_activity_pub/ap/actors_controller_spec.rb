# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ActorsController do
  let(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ObjectsController }

  context "without a valid actor" do
    it "returns a not found error" do
      get_object(actor, custom_url: "/ap/actor/56")
      expect(response.status).to eq(404)
      expect(response.parsed_body).to eq(activity_request_error("not_found"))
    end
  end

  context "without a public actor" do
    before do
      actor.model.set_permissions(admins: :full)
      actor.model.save!
    end

    it "returns a not available error" do
      get_object(actor)
      expect(response.status).to eq(401)
      expect(response.parsed_body).to eq(activity_request_error("not_available"))
    end
  end

  context "without activity pub ready on actor model" do
    it "returns a not available error" do
      get_object(actor)
      expect(response.status).to eq(403)
      expect(response.parsed_body).to eq(activity_request_error("not_available"))
    end
  end

  describe "#show" do
    before do
      toggle_activity_pub(actor.model)
    end

    it "returns actor json" do
      get_object(actor)
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(actor.ap.json)
    end
  end
end