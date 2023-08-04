# frozen_string_literal: true

module DiscourseActivityPub
  class CollectionStruct

    attr_reader :ap_id,
                :items

    def initialize(ap_id: nil, items: [])
      @ap_id = ap_id
      @items = items
    end
  end
end