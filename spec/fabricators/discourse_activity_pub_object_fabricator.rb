# frozen_string_literal: true

Fabricator(:discourse_activity_pub_object) do
  ap_type { "Object" }

  before_create do |object|
    if !object.local && !object.ap_id
      object.ap_id = "https://external.com/object/#{ap_type.downcase}/#{SecureRandom.hex(8)}"
    end
  end
end

Fabricator(:discourse_activity_pub_object_note, from: :discourse_activity_pub_object) do
  ap_type { DiscourseActivityPub::AP::Object::Note.type }
  model { Fabricate(:post) }
  local { true }

  after_create do |object|
    if object.model.respond_to?(:activity_pub_content)
      object.content = object.model.activity_pub_content
    else
      object.content = "I'm a note without a post"
    end
    object.save!
  end
end

Fabricator(:discourse_activity_pub_object_article, from: :discourse_activity_pub_object) do
  ap_type { DiscourseActivityPub::AP::Object::Article.type }
  model { Fabricate(:post) }
  local { true }

  after_create do |object|
    if object.model.respond_to?(:activity_pub_content)
      object.content = object.model.activity_pub_content
      object.save!
    end
  end
end