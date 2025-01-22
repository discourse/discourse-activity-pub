# frozen_string_literal: true

Fabricator(:discourse_activity_pub_log) do
  level { 1 } # warn
  message { sequence(:message) { |i| "ActivityPub log message #{i}" } }
end
