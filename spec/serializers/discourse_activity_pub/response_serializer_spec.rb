# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::ResponseSerializer do
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_accept) }

  def get_ap_response(activity)
    DiscourseActivityPub::AP::Activity::Response.new(stored: activity)
  end

  def get_serialized_ap_response(response)
    DiscourseActivityPub::AP::Activity::ResponseSerializer.new(response, root: false).as_json
  end

  it "serializes response attributes correctly" do
    response = get_ap_response(activity)
    serialized_response = get_serialized_ap_response(response)
    expect(serialized_response[:actor]).to eq(activity.actor.ap.json)
    expect(serialized_response[:object]).to eq(activity.object.ap.json)
  end
end
