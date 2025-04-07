# frozen_string_literal: true

Fabricator(:discourse_activity_pub_attachment) do
  ap_type { "Image" }
  media_type { "image/png" }

  before_create do |object|
    filename = "#{SecureRandom.hex(8)}-image"
    object.url = "https://local.com/attachment/image/#{filename}.png"
    object.name = filename
  end
end
