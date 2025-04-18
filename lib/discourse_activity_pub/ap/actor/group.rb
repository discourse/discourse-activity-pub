# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Group < Actor
        def type
          "Group"
        end

        def can_belong_to
          %i[category tag user remote]
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            create: %i[note article],
            delete: %i[note article group tombstone],
            update: %i[note article],
            announce: %i[create update delete like undo ordered_collection note article],
            follow: %i[group person],
            undo: [:follow],
          }
        end
      end
    end
  end
end
