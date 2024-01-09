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

      def shared_inbox
        stored&.shared_inbox
      end

      def preferred_username
        stored&.username
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

      def group?
        type == Group.type
      end

      def application?
        type == Application.type
      end

      def public_key
        return nil unless stored&.public_key
        { id: signature_key_id(stored), owner: id, publicKeyPem: stored.public_key }
      end

      def self.resolve_and_store(actor_id)
        super(actor_id)
      end
    end
  end
end
