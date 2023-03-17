# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module Concerns
      module Base
        extend ActiveSupport::Concern

        included do
          validates :uid, presence: true, uniqueness: true
          validates :ap_type, presence: true
        end

        def ap
          @ap ||= DiscourseActivityPub::AP::Object.get_klass(ap_type).new(stored: self)
        end
      end
    end
  end
end