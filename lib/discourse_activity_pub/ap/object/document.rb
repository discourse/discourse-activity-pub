# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Document < Object
        def type
          "Document"
        end

        def can_belong_to
          %i[remote]
        end
      end
    end
  end
end
