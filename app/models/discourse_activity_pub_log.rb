# frozen_string_literal: true

class DiscourseActivityPubLog < ActiveRecord::Base
  enum :level, %i[info warn error]

  validates :message, presence: true
  validates :level, presence: true
end

# == Schema Information
#
# Table name: discourse_activity_pub_logs
#
#  id         :bigint           not null, primary key
#  level      :integer
#  message    :string
#  json       :json
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
