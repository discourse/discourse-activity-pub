# frozen_string_literal: true
module DiscourseActivityPub
  class UserHandler
    attr_reader :actor

    def initialize(actor)
      @actor = actor
    end

    def find_or_create
      # We only associated users with stored Persons
      return nil unless actor.person? && actor.stored

      # Because we're dealing with a Person, the model will be the user
      return actor.stored.model if actor.stored.model.present?

      user = nil

      ActiveRecord::Base.transaction do
        begin
          user =
            User.create!(
              username: UserNameSuggester.suggest(actor.preferred_username.presence || actor.id),
              name: actor.name,
              staged: true,
              skip_email_validation: true
            )
        rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
          log_failure("find_or_create", e.message)
          raise ActiveRecord::Rollback
        end

        actor.stored.update(model_id: user.id, model_type: 'User')
      end

      user
    end

    def log_failure(verb, message)
      return unless SiteSetting.activity_pub_verbose_logging

      prefix = "Failed to #{verb} user for #{actor.id}"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
    end

    def self.find_or_create(actor)
      new(actor).find_or_create
    end
  end
end