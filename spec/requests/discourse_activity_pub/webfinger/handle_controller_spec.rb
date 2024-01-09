# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Webfinger::HandleController do
  describe "#validate" do
    it "validates a handle" do
      post "/webfinger/handle/validate", params: { handle: "username@domain.com" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["valid"]).to eq(true)
    end
  end
end
