# frozen_string_literal: true
module DiscourseActivityPub
  class ActorHandler
    include HasErrors

    MODEL_TYPES = %w[User Category]

    attr_accessor :opts

    def initialize(actor: nil, model: nil)
      @actor = actor
      @model = model
    end

    def model
      @model ||= actor&.reload&.model
    end

    def model_type
      @model_type ||= model&.class&.name
    end

    def actor
      @actor ||= model&.reload&.activity_pub_actor
    end

    def build_actor
      ap_type =
        case model_type
        when "User"
          DiscourseActivityPub::AP::Actor::Person.type
        when "Category"
          DiscourseActivityPub::AP::Actor::Group.type
        end
      attrs = { ap_type: ap_type, local: true }
      @actor = model.build_activity_pub_actor(attrs)
    end

    def build_model
      model.custom_fields["activity_pub_enabled"] = true
    end

    def update_or_create_user
      @model_type = "User"
      return invalid_opts unless valid_actor?

      ActiveRecord::Base.transaction do
        find_or_create_user unless model
        update_user
      end

      model
    end

    def update_or_create_actor(opts = {})
      @opts = opts

      return invalid_opts unless valid_model?
      return invalid_opts unless valid_actor_opts?

      ActiveRecord::Base.transaction do
        if !actor
          build_actor
          build_model
        end

        if can_admin_actor?
          update_actor_from_opts
          update_model_from_opts
        else
          update_actor_from_model
        end

        actor.save! if actor.new_record? || actor.changed?

        model.save_custom_fields(true) if can_admin_actor?
      end

      model.activity_pub_publish_state if can_admin_actor?

      actor.reload
    end

    def success?
      errors.blank?
    end

    def self.update_or_create_user(actor)
      return nil unless actor
      new(actor: actor).update_or_create_user
    end

    def self.update_or_create_actor(model, opts = {})
      return nil unless model
      new(model: model).update_or_create_actor(opts)
    end

    def self.find_user_by_stored_actor_id(actor_id)
      return nil unless actor_id

      User
        .joins(:activity_pub_actor)
        .where("discourse_activity_pub_actors.ap_id = :actor_id", actor_id: actor_id)
        .first
    end

    def self.find_user_by_authorized_actor_id(actor_id)
      return nil unless actor_id

      User
        .joins(:user_custom_fields)
        .where(
          "
          user_custom_fields.name = 'activity_pub_actor_ids' AND
          user_custom_fields.value::jsonb ? :actor_id",
          actor_id: actor_id.to_s,
        )
        .first
    end

    protected

    def update_avatar_from_icon
      if update_avatar?
        icon_upload = Upload.find_by(user_id: model.id, origin: actor.icon_url)

        if !icon_upload
          UserAvatar.import_url_for_user(actor.icon_url, model)
        elsif model.uploaded_avatar_id != icon_upload.id
          model.update!(uploaded_avatar_id: icon_upload.id)
        end
      end
    end

    def update_avatar?
      return false unless actor.icon_url
      return true if !model || model.uploaded_avatar.blank?

      DiscourseActivityPub::URI.matching_hosts?(actor.icon_url, model.uploaded_avatar.origin)
    end

    def find_or_create_user
      @model = self.class.find_user_by_authorized_actor_id(actor.ap_id)

      unless model
        begin
          @model =
            User.create!(
              username: UserNameSuggester.suggest(actor.username.presence || actor.id),
              name: actor.name,
              staged: true,
              skip_email_validation: true,
            )
        rescue PG::UniqueViolation,
               ActiveRecord::RecordNotUnique,
               ActiveRecord::RecordInvalid => error
          DiscourseActivityPub::Logger.error(
            I18n.t(
              "discourse_activity_pub.user.error.failed_to_create",
              actor_id: actor.ap_id,
              message: error.message,
            ),
          )
          raise ActiveRecord::Rollback
        end
      end

      actor.update(model_id: model.id, model_type: "User") unless model.activity_pub_actor.present?
    end

    def update_user
      model.skip_email_validation = true
      update_avatar_from_icon
    end

    def update_actor_from_model
      username = model.activity_pub_username

      username = UsernameSuggester.suggest(username) if !valid_actor_username?(username)

      actor.username = username
      actor.name = model.activity_pub_name if model.activity_pub_name
    end

    def update_actor_from_opts
      return unless opts.present?
      actor.name = opts[:name] if opts[:name].present?
      actor.username = opts[:username] if opts[:username].present?
    end

    def update_model_from_opts
      return unless opts.present?
      DiscourseActivityPubActor::CUSTOM_FIELDS.each do |field|
        model.custom_fields["activity_pub_#{field}"] = opts[field]
      end
    end

    def can_admin_actor?
      DiscourseActivityPubActor::ADMIN_MODELS.include?(model_type) && opts.present?
    end

    def valid_actor_username?(username)
      UsernameValidator.new(username).valid_format?
    end

    def unique_actor_username?(username)
      DiscourseActivityPubActor.username_unique?(username, model_id: model.id)
    end

    def username_changed?
      (opts[:username].present? && actor && actor.username.present?) &&
        actor.username != opts[:username]
    end

    def valid_actor?
      if !actor&.ap&.can_belong_to&.include?(model_type.downcase.to_sym)
        add_error(
          I18n.t(
            "discourse_activity_pub.actor.warning.cant_create_model_for_actor_type",
            actor_id: actor.ap_id,
            actor_type: actor.ap_type,
          ),
        )
        false
      else
        true
      end
    end

    def valid_model?
      if !MODEL_TYPES.include?(model_type)
        add_error(
          I18n.t(
            "discourse_activity_pub.actor.warning.cant_create_actor_for_model_type",
            model_id: model.id,
            model_type: model_type,
          ),
        )
        return false
      end
      if !model.activity_pub_allowed?
        add_error(
          I18n.t(
            "discourse_activity_pub.actor.warning.not_allowed_to_create_actor_for_model",
            model_id: model.id,
          ),
        )
        return false
      end
      true
    end

    def valid_actor_opts?
      return true if model_type == "User"
      return invalid_opt("no_options") if opts.blank?

      if opts[:username].present?
        return invalid_opt("no_change_when_set") if username_changed?
        return invalid_opt("invalid_username") if !valid_actor_username?(opts[:username])
        return invalid_opt("username_taken") if !unique_actor_username?(opts[:username])
      end

      true
    end

    def invalid_opt(key)
      add_error(I18n.t("discourse_activity_pub.actor.warning.#{key}"))
      false
    end

    def invalid_opts
      log_errors
      nil
    end

    def log_errors
      errors.each { |error| DiscourseActivityPub::Logger.warn(error.message) }
    end
  end
end
