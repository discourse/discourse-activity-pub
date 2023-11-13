# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Group < Actor
        def type
          'Group'
        end

        def can_belong_to
          %i(category remote)
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            create: [:note, :article],
            delete: [:note, :article],
            update: [:note, :article],
            announce: [:create, :update, :delete, :ordered_collection],
            follow: [:group, :person]
          }
        end
      end
    end
  end
end