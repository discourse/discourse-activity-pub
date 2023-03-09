# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Follow do
  let(:category) { Fabricate(:category) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
      type: described_class.type,
      actor: {
        id: "https://external.com/u/angus",
        type: "Person",
        inbox: "https://external.com/u/angus/inbox",
        outbox: "https://external.com/u/angus/outbox"
      },
      object: category.full_url,
    }.with_indifferent_access
  end

  def build_warning(key, object_id)
    action = I18n.t("discourse_activity_pub.activity.warning.failed_to_process", object_id: object_id)
    message = I18n.t("discourse_activity_pub.activity.warning.#{key}")
    "[Discourse Activity Pub] #{action}: #{message}"
  end

  def perform_process(json)
    klass = described_class.new
    klass.json = json
    klass.send(:process_json)
  end

  describe '#process_json' do
    before do
      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after do
      Rails.logger = @orig_logger
    end

    context "with a valid follow" do
      context 'without activity pub enabled on the model' do
        it "returns false" do
          expect(perform_process(json)).to eq(false)
        end

        it "creates an actor" do
          perform_process(json)
          expect(DiscourseActivityPubActor.exists?(uid: json['actor']['id'])).to eq(true)
        end

        it "logs a warning" do
          perform_process(json)
          expect(@fake_logger.warnings.last).to match(
            build_warning("activity_not_enabled", json['id'])
          )
        end
      end

      context 'with activity pub enabled on the model' do
        before do
          category.custom_fields["activity_pub_enabled"] = true
          category.save!
        end

        it "returns an actor and model" do
          expect(perform_process(json)).to eq([
            DiscourseActivityPubActor.find_by(uid: json['actor']['id']),
            category
          ])
        end

        it "does not log a warning" do
          perform_process(json)
          expect(@fake_logger.warnings.any?).to eq(false)
        end
      end
    end

    context "with an invalid follow" do
      context "with an unspported actor" do
        before do
          json["actor"]["type"] = "Group"
          perform_process(json)
        end

        it "returns false" do
          expect(perform_process(json)).to eq(false)
        end

        it "does not create an actor" do
          expect(
            DiscourseActivityPubActor.exists?(
              uid: json['actor']['id']
            )
          ).to eq(false)
        end

        it "logs a warning" do
          expect(@fake_logger.warnings.last).to match(
            build_warning("actor_not_supported", json['id'])
          )
        end
      end

      context "with an invalid object" do
        before do
          json["object"] = "https://anotherforum.com#{category.url}"
          perform_process(json)
        end

        it "returns false" do
          expect(perform_process(json)).to eq(false)
        end

        it "creates an actor" do
          expect(DiscourseActivityPubActor.exists?(uid: json['actor']['id'])).to eq(true)
        end

        it "logs a warning" do
          expect(@fake_logger.warnings.last).to match(
            build_warning("object_not_valid", json["id"])
          )
        end
      end
    end
  end
end
