# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::ResponseSerializer do
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_accept) }

  def build_response(activity)
    DiscourseActivityPub::AP::Activity::Response.new(activity: activity)
  end

  def serialize_response(response)
    DiscourseActivityPub::AP::Activity::ResponseSerializer.new(response, root: false).as_json
  end

  it "serializes response attributes correctly" do
    serialized = serialize_response(build_response(activity))
    expect(serialized[:actor]).to eq(activity.actor.uid)
    expect(serialized[:object]).to eq(activity.object.uid)
  end
end
