# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::UsernameValidator do
  def expect_valid(*usernames)
    usernames.each do |username|
      validator = DiscourseActivityPub::UsernameValidator.new(username)

      aggregate_failures do
        expect(validator.valid_format?).to eq(true), "expected '#{username}' to be valid"
        expect(validator.errors).to be_empty
      end
    end
  end

  def expect_invalid(*usernames, error_message:)
    usernames.each do |username|
      validator = DiscourseActivityPub::UsernameValidator.new(username)

      aggregate_failures do
        expect(validator.valid_format?).to eq(false), "expected '#{username}' to be invalid"
        expect(validator.errors).to include(error_message)
      end
    end
  end

  shared_examples "ActivityPub ASCII username" do
    it "is invalid when the username is less than core site setting" do
      SiteSetting.min_username_length = 4

      expect_invalid("a", "ab", "abc", error_message: I18n.t(:"user.username.short", count: 4))
    end

    it "is valid when the username is more than core site setting" do
      SiteSetting.min_username_length = 4

      expect_valid("abcd")
    end

    it "is invalid when the username is longer than core site setting" do
      SiteSetting.max_username_length = 8

      expect_invalid("abcdefghi", error_message: I18n.t(:"user.username.long", count: 8))
    end

    it "is valid when the username contains alphanumeric characters, dots, underscores and dashes" do
      expect_valid("ab-cd.123_ABC-xYz")
    end

    it "is invalid when the username contains non-alphanumeric characters other than dots, underscores and dashes" do
      expect_invalid("abc|", "a#bc", "abc xyz", error_message: I18n.t(:"user.username.characters"))
    end
  end

  context "when Unicode usernames are enabled" do
    before { SiteSetting.unicode_usernames = true }

    context "with ActivityPub ASCII usernames" do
      include_examples "ActivityPub ASCII username"
    end

    context "with ActivityPub Non-ASCII usernames" do
      it "is invalid when the username contains non-ASCII characters except dots, underscores and dashes" do
        expect_invalid("abcö", "abc象", error_message: I18n.t(:"user.username.characters"))
      end
    end
  end
end
