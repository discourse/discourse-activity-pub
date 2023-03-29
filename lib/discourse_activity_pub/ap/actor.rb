# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor < Object

      def base_type
        'Actor'
      end

      def domain
        stored&.domain
      end

      def preferred_username
        stored&.username
      end

      def can_belong_to
        %i()
      end

      def can_perform_activity
        {}
      end

      def changeable_attributes
        {
          name: 'name'
        }
      end

      def update_stored_from_json
        return false unless json
        @stored = DiscourseActivityPubActor.find_by(ap_id: json[:id])

        unless stored
          @stored = DiscourseActivityPubActor.new(
            ap_id: json[:id],
            ap_type: json[:type],
            domain: domain_from_id(json[:id]),
            username: json[:preferredUsername],
            inbox: json[:inbox],
            outbox: json[:outbox]
          )
        end

        changeable_attributes.each do |column, attribute|
          stored.send("#{column}=", json[attribute]) if json[attribute].present?
        end

        stored.save! if stored.new_record? || stored.changed?

        stored
      end
    end
  end
end