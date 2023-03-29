# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Follow do
  let(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

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

    context "with a valid activity" do
      before do
        @json = build_follow_json(actor)
      end

      context "without activity pub enabled" do
        before do
          toggle_activity_pub(actor.model, disable: true)
        end

        it "returns false" do
          expect(perform_process(@json)).to eq(false)
        end

        it "creates a actor" do
          perform_process(@json)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json['actor']['id'])).to eq(true)
        end

        it "logs a warning" do
          perform_process(@json)
          expect(@fake_logger.warnings.last).to match(
            build_warning("activity_not_available", @json['id'])
          )
        end
      end

      context "with activity pub enabled" do
        before do
          toggle_activity_pub(actor.model)
        end

        it "returns an actor and model" do
          expect(perform_process(@json)).to eq([
            DiscourseActivityPubActor.find_by(ap_id: @json['actor']['id']),
            actor.model
          ])
        end

        it "does not log a warning" do
          perform_process(@json)
          expect(@fake_logger.warnings.any?).to eq(false)
        end
      end
    end

    context "with an invalid activity" do
      context "with an unspported actor" do
        before do
          @json = build_follow_json(actor)
          @json["actor"]["type"] = "Group"
        end

        it "returns false" do
          expect(perform_process(@json)).to eq(false)
        end

        it "does not create an actor" do
          perform_process(@json)
          expect(
            DiscourseActivityPubActor.exists?(
              ap_id: @json['actor']['id']
            )
          ).to eq(false)
        end

        it "logs a warning" do
          perform_process(@json)
          expect(@fake_logger.warnings.last).to match(
            build_warning("actor_not_supported", @json['id'])
          )
        end
      end

      context "with an invalid object" do
        before do
          @json = build_follow_json
        end

        it "returns false" do
          expect(perform_process(@json)).to eq(false)
        end

        it "creates an actor" do
          perform_process(@json)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json['actor']['id'])).to eq(true)
        end

        it "logs a warning" do
          perform_process(@json)
          expect(@fake_logger.warnings.last).to match(
            build_warning("object_not_valid", @json["id"])
          )
        end
      end
    end
  end
end
