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

        def in_reply_to
          stored&.reply_to_id
        end

        def can_belong_to
          %i(post remote)
        end
      end
    end
  end
end