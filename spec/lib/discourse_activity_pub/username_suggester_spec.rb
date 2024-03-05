# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::UsernameSuggester do
  describe "#suggest" do
    it "converts non-valid usernames to valid usernames" do
      expect(described_class.suggest("零卡")).to eq(I18n.t("fallback_username"))
    end

    it "works with non-latin locales" do
      expect(I18n.with_locale(:zh_TW) { described_class.suggest("零卡") }).to eq(
        described_class::LAST_RESORT_USERNAME,
      )
    end

    it "returns locally unique usernames" do
      expect(described_class.suggest("à")).to eq("a")
      Fabricate(:discourse_activity_pub_actor, username: "a", local: true)
      expect(described_class.suggest("à")).to eq("a1")
      Fabricate(:discourse_activity_pub_actor, username: "a1", local: true)
      expect(described_class.suggest("à")).to eq("a2")
      Fabricate(:discourse_activity_pub_actor, username: "a2", local: false)
      Fabricate(:discourse_activity_pub_actor, username: "a10", local: true)
      expect(described_class.suggest("à")).to eq("a2")
      expect(described_class.suggest("a10")).to eq("a101")
    end
  end
end
