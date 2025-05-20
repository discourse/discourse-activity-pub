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
          return stored.reply_to_id if stored
          json["inReplyTo"] if json
        end

        def can_belong_to
          %i[post remote]
        end
      end
    end
  end
end
