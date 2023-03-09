# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor < Object

      attr_accessor :actor

      def initialize(actor: nil)
        @actor = actor
      end

      def domain
        domain_from_id(id)
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

      def create_or_update_from_json
        return false unless json

        @actor = DiscourseActivityPubActor.find_by(uid: id)

        unless actor
          @actor = DiscourseActivityPubActor.new(
            uid: id,
            domain: domain,
            ap_type: type,
            inbox: json[:inbox],
            outbox: json[:outbox]
          )
        end

        optional_attributes.each do |column, attribute|
          actor.send("#{column}=", json[attribute]) if json[attribute].present?
        end

        actor.save! if actor.new_record? || actor.changed?

        actor
      end

      def self.ensure_for(model)
        if model.activity_pub_enabled && !model.activity_pub_actor
          model.build_activity_pub_actor(
            uid: model.full_url,
            domain: Discourse.current_hostname,
            ap_type: model.activity_pub_type
          )
          model.save!
        end
      end
    end
  end
end