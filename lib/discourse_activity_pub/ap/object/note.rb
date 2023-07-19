# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Note < Object

        def type
          "Note"
        end

        def content
          stored&.content
        end

        def updated
          stored&.updated_at.iso8601
        end

        def in_reply_to
          stored&.in_reply_to
        end

        def can_belong_to
          %i(post remote)
        end
      end
    end
  end
end