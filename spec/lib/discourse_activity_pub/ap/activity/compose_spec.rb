# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Compose do
  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }
end