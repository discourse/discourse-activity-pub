# frozen_string_literal: true

# TODO: PR discourse/discourse to support alternate username uses

class DiscourseActivityPub::UsernameValidator < UsernameValidator
  def user
    nil
  end

  def self.invalid_char_pattern
    UsernameValidator::ASCII_INVALID_CHAR_PATTERN
  end

  def self.char_allowlist_exists?
    false
  end
end