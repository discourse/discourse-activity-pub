# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Group < Actor
        def type
          'Group'
        end

        def can_belong_to
          %i(category)
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            create: [:note],
            delete: [:note]
          }
        end
      end
    end
  end
end