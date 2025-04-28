# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Tombstone < Object
        def type
          "Tombstone"
        end

        def can_belong_to
          %i[category tag user post remote]
        end
      end
    end
  end
end
