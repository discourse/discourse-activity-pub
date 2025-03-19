# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Image < Object
        def type
          "Image"
        end

        def can_belong_to
          %i[remote]
        end
      end
    end
  end
end
