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

      def public_key
        return nil unless stored&.public_key
        {
          id: signature_key_id(stored),
          owner: id,
          publicKeyPem: stored.public_key
        }
      end

      def update_stored_from_json(stored_id = nil)
        return false unless json
        @stored = DiscourseActivityPubActor.find_by(ap_id: json[:id])

        # id has changed
        if !stored && stored_id
          @stored = DiscourseActivityPubActor.find_by(ap_id: stored_id)
          stored.ap_id = json[:id]
        end

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

        if json['publicKey'].is_a?(Hash) && json['publicKey']['owner'] == stored.ap_id
          stored.public_key = json['publicKey']['publicKeyPem']
        end

        stored.save! if stored.new_record? || stored.changed?

        stored
      end

      def self.resolve_and_store(actor_id, stored: false)
        resolved_actor = DiscourseActivityPub::JsonLd.resolve_object(actor_id)
        return process_failed(actor_id, "cant_resolve_actor") unless resolved_actor.present?

        ap_actor = factory(resolved_actor)
        return process_failed(resolved_actor['id'], "actor_not_supported") unless ap_actor.can_belong_to.include?(:remote)

        ap_actor.update_stored_from_json(stored ? actor_id : nil)
      end
    end
  end
end