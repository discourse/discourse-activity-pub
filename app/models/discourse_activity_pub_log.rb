# frozen_string_literal: true

class DiscourseActivityPubLog < ActiveRecord::Base
  enum :level, %i[info warn error]

  validates :message, presence: true
  validates :level, presence: true
end
