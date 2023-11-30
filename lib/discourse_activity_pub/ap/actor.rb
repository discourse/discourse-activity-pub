# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor < Object
      def base_type
        "Actor"
      end

      def domain
        stored&.domain
      end

      def inbox
        stored&.inbox
      end

      def outbox
        stored&.outbox
      end

      def preferred_username
        stored&.username
      end

      def name
        stored&.name
      end

      def icon_url
        stored&.icon_url
      end

      def icon_media_type
        "image/png"
      end

      def can_belong_to
        %i[]
      end

      def can_perform_activity
        {}
      end

      def person?
        type == Person.type
      end

      def public_key
        return nil unless stored&.public_key
        { id: signature_key_id(stored), owner: id, publicKeyPem: stored.public_key }
      end

      def update_stored_from_json(stored_id = nil)
        return false unless json

        DiscourseActivityPubActor.transaction do
          @stored = DiscourseActivityPubActor.find_by(ap_id: json[:id])

          # id has changed
          if !stored && stored_id
            @stored = DiscourseActivityPubActor.find_by(ap_id: stored_id)
            stored.ap_id = json[:id]
          end

          if !stored
            @stored =
              DiscourseActivityPubActor.new(
                ap_id: json[:id],
                ap_type: json[:type],
                domain: domain_from_id(json[:id]),
                username: json[:preferredUsername],
                inbox: json[:inbox],
                outbox: json[:outbox],
                name: json[:name],
                icon_url: resolve_icon_url(json[:icon]),
              )
          else
            stored.name = json[:name] if json[:name].present?
            stored.icon_url = resolve_icon_url(json[:icon]) if json[:icon].present?
          end

          if json["publicKey"].is_a?(Hash) && json["publicKey"]["owner"] == stored.ap_id
            stored.public_key = json["publicKey"]["publicKeyPem"]
          end

          if stored.new_record? || stored.changed?
            begin
              stored.save!
            rescue ActiveRecord::RecordInvalid => error
              log_stored_save_error(error, json)
            end
          end
        end

        stored
      end

      def self.resolve_and_store(actor_id, stored: false)
        resolved_actor = DiscourseActivityPub::JsonLd.resolve_object(actor_id)
        return process_failed(actor_id, "cant_resolve_actor") unless resolved_actor.present?

        ap_actor = factory(resolved_actor)
        unless ap_actor&.can_belong_to.include?(:remote)
          return process_failed(resolved_actor["id"], "actor_not_supported")
        end

        ap_actor.update_stored_from_json(stored ? actor_id : nil)

        ap_actor
      end
    end
  end
end
