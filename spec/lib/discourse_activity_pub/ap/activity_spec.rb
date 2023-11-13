# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity do
  let(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Object }

  def perform_process(json, activity_type)
    klass = described_class.new
    klass.json = json
    klass.stubs(:type).returns(activity_type)
    klass.send(:process_actor_and_object)
  end

  describe '#process_actor_and_object' do
    let(:activity_type) { DiscourseActivityPub::AP::Activity::Follow.type }

    context "with a valid activity" do
      before do
        @json = build_activity_json(object: actor, type: activity_type)
      end

      context "without activity pub enabled" do
        before do
          toggle_activity_pub(actor.model, disable: true)
        end

        it "returns false" do
          expect(perform_process(@json, activity_type)).to eq(false)
        end

        it "creates a actor" do
          perform_process(@json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json['actor']['id'])).to eq(true)
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
          end

          before do
            @orig_logger = Rails.logger
            Rails.logger = @fake_logger = FakeLogger.new
          end

          after do
            Rails.logger = @orig_logger
          end

          it "logs a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.last).to match(
              build_process_warning("object_not_ready", @json['id'])
            )
          end
        end
      end

      context "with activity pub enabled" do
        before do
          toggle_activity_pub(actor.model)
        end

        it "returns true" do
          expect(perform_process(@json, activity_type)).to eq(true)
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
          end

          before do
            @orig_logger = Rails.logger
            Rails.logger = @fake_logger = FakeLogger.new
          end

          after do
            Rails.logger = @orig_logger
          end

          it "does not log a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.any?).to eq(false)
          end
        end
      end
    end

    context "with an invalid activity" do
      context "with an unspported actor" do
        before do
          @json = build_activity_json(object: actor, type: activity_type)
          @json["actor"]["type"] = "Service"
        end

        it "returns false" do
          expect(perform_process(@json, activity_type)).to eq(false)
        end

        it "does not create an actor" do
          perform_process(@json, activity_type)
          expect(
            DiscourseActivityPubActor.exists?(
              ap_id: @json['actor']['id']
            )
          ).to eq(false)
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
          end

          before do
            @orig_logger = Rails.logger
            Rails.logger = @fake_logger = FakeLogger.new
          end

          after do
            Rails.logger = @orig_logger
          end

          it "logs a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.first).to match(
              build_process_warning("actor_not_supported", @json["actor"]['id'])
            )
          end
        end
      end

      context "with an invalid object" do
        before do
          @json = build_activity_json
        end

        it "returns false" do
          expect(perform_process(@json, activity_type)).to eq(false)
        end

        it "creates an actor" do
          perform_process(@json, activity_type)
          expect(DiscourseActivityPubActor.exists?(ap_id: @json['actor']['id'])).to eq(true)
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
          end

          before do
            @orig_logger = Rails.logger
            Rails.logger = @fake_logger = FakeLogger.new
          end

          after do
            Rails.logger = @orig_logger
          end

          it "logs a warning" do
            perform_process(@json, activity_type)
            expect(@fake_logger.warnings.last).to match(
              build_process_warning("cant_find_object", @json["id"])
            )
          end
        end
      end
    end
  end
end
