# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Person < Actor
        def type
          'Person'
        end

        def can_belong_to
          %i(remote user)
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            follow: [:group],
            undo: [:follow, :like],
            create: [:note, :article],
            update: [:note, :article],
            delete: [:note, :article],
            like: [:note, :article]
          }
        end
      end
    end
  end
end