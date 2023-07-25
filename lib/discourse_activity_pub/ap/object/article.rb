# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Article < Object

        def type
          "Article"
        end

        def content
          stored&.content
        end

        def updated
          stored&.updated_at.iso8601
        end

        def can_belong_to
          %i(post)
        end
      end
    end
  end
end