# frozen_string_literal: true

class DiscourseActivityPubAuthorization < ActiveRecord::Base
  belongs_to :user
  belongs_to :actor, class_name: "DiscourseActivityPubActor"

  before_save :ensure_keys, if: :discourse?

  def discourse?
    auth_type === self.class.auth_types[:discourse]
  end

  def mastodon?
    auth_type === self.class.auth_types[:mastodon]
  end

  def auth_type_name
    auth_type && self.class.auth_types[auth_type]
  end

  def self.auth_types
    @auth_types ||= Enum.new(discourse: 1, mastodon: 2)
  end

  protected

  def ensure_keys
    return unless discourse? && private_key.blank? && public_key.blank?
    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key = keypair.public_key.to_pem
    save!
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_authorizations
#
#  id          :bigint           not null, primary key
#  user_id     :integer          not null
#  actor_id    :integer
#  domain      :string
#  auth_type   :integer
#  token       :string
#  private_key :text
#  public_key  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#  fk_rails_...  (user_id => users.id)
#
