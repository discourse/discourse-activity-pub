# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)

  describe "#suspend" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, local: false) }

    before { sign_in(admin) }

    it "suspends a user created from a remote activitypub actor" do
      user = DiscourseActivityPub::ActorHandler.update_or_create_user(actor)

      put "/admin/users/#{user.id}/suspend.json",
          params: {
            suspend_until: 5.hours.from_now,
            reason: "because I said so",
          }

      expect(response.status).to eq(200)

      user.reload
      expect(user).to be_suspended
      expect(user.suspended_at).to be_present
      expect(user.suspended_till).to be_present
      expect(user.suspend_record).to be_present

      log = UserHistory.where(target_user_id: user.id).order("id desc").first
      expect(log.details).to match(/because I said so/)
    end
  end
end
