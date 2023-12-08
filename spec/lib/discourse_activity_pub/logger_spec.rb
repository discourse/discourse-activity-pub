# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Logger do
  describe "#log" do
    let!(:default_message) { 'log message' }
    let!(:prefixed_message) { "#{described_class::PREFIX} #{default_message}" }

    before do
      @orig_rails_logger = Rails.logger
      @orig_ap_logger = DiscourseActivityPub::AP.logger
      Rails.logger = @rails_logger = FakeLogger.new
      DiscourseActivityPub::AP.logger = @ap_logger = FakeLogger.new
      freeze_time
    end

    after do
      Rails.logger = @orig_rails_logger
      DiscourseActivityPub::AP.logger = @orig_ap_logger
    end

    def perform(type: :error, message: default_message, json: {})
      described_class.new(type).log(message, json: json)
    end

    context "with verbose logging disabled" do
      before do 
        SiteSetting.activity_pub_verbose_logging = false
      end

      it "does not log anything" do
        expect(perform).to eq(nil)
        expect(@rails_logger.errors.present?).to eq(false)
        expect(@ap_logger.errors.present?).to eq(false)
      end
    end

    context "with verbose logging enabled" do
      before do 
        SiteSetting.activity_pub_verbose_logging = true
      end

      it "returns true" do
        expect(perform).to eq(true)
      end

      it "logs a prefixed message in rails" do
        perform
        expect(@rails_logger.errors.first).to eq(prefixed_message)
      end

      it "does not log anything in activitypub" do
        perform
        expect(@ap_logger.errors.present?).to eq(false)
      end

      context "when in a development environment" do
        before do
          Rails.env.stubs(:development?).returns(true)
        end

        it "logs a prefixed message in activitypub" do
          perform
          expect(@ap_logger.errors.first).to eq(prefixed_message)
        end

        context "when given a JSON object" do
          let!(:json) { { "key1": "value1", "key2": "value2" } }
  
          it "does not add anything to the rails log" do
            perform(json: json)
            expect(@rails_logger.errors.first).to eq(prefixed_message)
          end
  
          it "adds a YAML representation of the JSON to the activitypub log" do
            perform(json: json)
            expect(@ap_logger.errors.first).to eq("#{prefixed_message}\n#{json.to_yaml}")
          end
        end
      end
    end
  end
end