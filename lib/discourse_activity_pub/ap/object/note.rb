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

        def can_belong_to
          %i(post)
        end
      end
    end
  end
end