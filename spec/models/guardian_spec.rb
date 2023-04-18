# frozen_string_literal: true

RSpec.describe Guardian do
  let!(:user) { Fabricate(:user) }
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, user: user, category: category) }
  let!(:post) { Fabricate(:post, user: user, topic: topic) }

  describe "#can_recover_post?" do
    context "with activity pub enabled" do
      before do
        toggle_activity_pub(category, callbacks: true)
      end

      context "as an admin" do
        let!(:admin) { Fabricate(:user, admin: true) }

        context "when post is destroyed" do
          before do
            PostDestroyer.new(admin, post).destroy
          end

          context "while in pre publication period" do
            it "allows recovery" do
              expect(Guardian.new(admin).can_recover_post?(post.reload)).to be_truthy
            end
          end

          context "after publication" do
            before do
              post.activity_pub_after_publish(Time.now)
            end

            it "allows edits" do
              expect(Guardian.new(admin).can_recover_post?(post.reload)).to be_falsey
            end
          end
        end
      end
    end
  end

  describe "#can_edit_post?" do
    context "with activity pub enabled" do
      before do
        toggle_activity_pub(category, callbacks: true)
      end

      context "as an admin" do
        let!(:admin) { Fabricate(:user, admin: true) }

        context "while in pre publication period" do
          it "allows edits" do
            expect(Guardian.new(admin).can_edit?(post)).to be_truthy
          end
        end

        context "after publication" do
          before do
            post.activity_pub_after_publish(Time.now)
          end

          it "allows edits" do
            expect(Guardian.new(admin).can_edit?(post)).to be_truthy
          end
        end
      end
    end
  end
end
