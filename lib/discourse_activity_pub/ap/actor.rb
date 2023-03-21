# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor < Object

      def domain
        model&.domain
      end

      def can_belong_to
        %i()
      end

      def can_perform_activity
        {}
      end

      def optional_attributes
        {
          preferred_username: 'preferredUsername',
          name: 'name'
        }
      end

      def update_stored_from_json
        return false unless json

        @stored = DiscourseActivityPubActor.find_by(uid: json[:id])

        unless stored
          @stored = DiscourseActivityPubActor.new(
            uid: json[:id],
            domain: domain_from_id(json[:id]),
            ap_type: json[:type],
            inbox: json[:inbox],
            outbox: json[:outbox]
          )
        end

        optional_attributes.each do |column, attribute|
          stored.send("#{column}=", json[attribute]) if json[attribute].present?
        end

        stored.save! if stored.new_record? || stored.changed?

        stored
      end
    end
  end
end