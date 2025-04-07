# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      class Document < Object
        def type
          "Document"
        end

        def media_type
          if stored && stored.respond_to?(:media_type)
            stored.media_type
          elsif json
            json[:mediaType]
          end
        end

        def can_belong_to
          %i[remote]
        end
      end
    end
  end
end
