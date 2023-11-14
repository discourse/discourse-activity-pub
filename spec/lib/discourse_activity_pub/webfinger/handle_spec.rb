# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Webfinger::Handle do
  describe "#valid?" do
    it "validates a valid handle" do
      expect(described_class.new("username@domain.com").valid?).to eq(true)
    end

    it "does not validate a handle with an invalid domain" do
      expect(described_class.new("username@#.com").valid?).to eq(false)
    end

    it "does not validate a handle with an invalid username" do
      expect(described_class.new("@domain.com").valid?).to eq(false)
    end

    it "removes a leading @ from the username" do
      handle = described_class.new("@username@domain.com")
      expect(handle.valid?).to eq(true)
      expect(handle.username).to eq("username")
    end
  end
end