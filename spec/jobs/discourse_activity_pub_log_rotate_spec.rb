# frozen_string_literal: true

RSpec.describe Jobs::DiscourseActivityPub::LogRotate do
  let!(:log1) { Fabricate(:discourse_activity_pub_log, created_at: 1.day.ago) }
  let!(:log2) { Fabricate(:discourse_activity_pub_log, created_at: 10.days.ago) }
  let!(:log3) { Fabricate(:discourse_activity_pub_log, created_at: 90.days.ago) }

  it "destroys logs older than activity_pub_logs_max_days_old" do
    SiteSetting.activity_pub_logs_max_days_old = 7
    described_class.new.execute({})
    expect(DiscourseActivityPubLog.exists?(log1.id)).to eq(true)
    expect(DiscourseActivityPubLog.exists?(log2.id)).to eq(false)
    expect(DiscourseActivityPubLog.exists?(log3.id)).to eq(false)
  end
end
