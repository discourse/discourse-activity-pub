# frozen_string_literal: true

Fabricator(:discourse_activity_pub_object) do
  uid { sequence(:uid) { |i| "object#{i}"} }
  ap_type { "Object" }
end

Fabricator(:discourse_activity_pub_object_note, from: :discourse_activity_pub_object) do
  ap_type { DiscourseActivityPub::AP::Object::Note.type }
  model { Fabricate(:post) }

  after_create do |object|
    if object.model.respond_to?(:activity_pub_content)
      object.content = object.model.activity_pub_content
    end
  end
end
