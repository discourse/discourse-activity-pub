# frozen_string_literal: true

module DiscourseActivityPub
  module Admin
    class ActorController < DiscourseActivityPub::Admin::AdminController
      before_action :find_actor, only: %i[show update enable disable]
      before_action :find_model, only: [:create]
      before_action :validate_actor_params, only: %i[create update]

      LIST_LIMIT = 30

      def index
        params.require(:model_type)

        model_type = params[:model_type].to_s.classify
        if DiscourseActivityPubActor::ACTIVE_MODELS.exclude?(model_type)
          return render_error("invalid_model", 400)
        end

        actors = DiscourseActivityPubActor.where(model_type: model_type, local: true)

        actors = actors.joins(:category) if model_type == "Category"
        actors = actors.joins(:tag) if model_type == "Tag"

        offset = params[:offset].to_i || 0
        load_more_query_params = { offset: offset + 1, model_type: model_type.downcase }
        load_more_query_params[:order] = params[:order] if !params[:order].nil?
        load_more_query_params[:asc] = params[:asc] if !params[:asc].nil?

        total = actors.count
        order =
          case params[:order]
          when "actor"
            "discourse_activity_pub_actors.name"
          when "model"
            case model_type.downcase
            when "category"
              "categories.name"
            when "tag"
              "tags.name"
            end
          else
            "discourse_activity_pub_actors.created_at"
          end
        direction = params[:asc] == "true" ? "ASC" : "DESC"
        actors = actors.order("#{order} #{direction}").limit(LIST_LIMIT).offset(offset * LIST_LIMIT)

        load_more_url = URI("/admin/plugins/ap/actor.json")
        load_more_url.query = ::URI.encode_www_form(load_more_query_params)

        render_serialized(
          actors,
          DiscourseActivityPub::DetailedActorSerializer,
          root: "actors",
          meta: {
            total: total,
            load_more_url: load_more_url.to_s,
          },
        )
      end

      def show
        render_serialized(@actor, DiscourseActivityPub::DetailedActorSerializer, root: false)
      end

      def create
        update_or_create
      end

      def update
        update_or_create
      end

      def enable
        if @actor.enable!
          render json: success_json
        else
          render json: failed_json
        end
      end

      def disable
        if @actor.disable!
          render json: success_json
        else
          render json: failed_json
        end
      end

      protected

      def update_or_create
        handler = ActorHandler.new(model: @model)

        actor_params[:model_id] = @model.id if actor_params[:model_type] === Tag
        actor = handler.update_or_create_actor(actor_params)

        if handler.success?
          render json:
                   success_json.merge(
                     actor:
                       DiscourseActivityPub::DetailedActorSerializer.new(
                         actor,
                         root: false,
                       ).as_json,
                   )
        else
          render json: failed_json.merge(errors: handler.errors.map(&:message)), status: 400
        end
      end

      def validate_actor_params
        if actor_params[:username].blank? && action_name === "create"
          return render_error("username_required", 400)
        end
        if actor_params[:publication_type] == "full_topic" &&
             actor_params[:default_visibility] == "private"
          render_error("full_topic_must_be_public", 400)
        end
      end

      def find_actor
        @actor =
          DiscourseActivityPubActor.find_by(
            id: params[:actor_id],
            model_type: DiscourseActivityPubActor::ACTIVE_MODELS,
          )
        return render_error("actor_not_found", 404) if @actor.blank?
        @model = @actor.model
      end

      def find_model
        if (actor_params[:model_id].blank? && actor_params[:model_name].blank?) ||
             actor_params[:model_type].blank?
          return render_error("invalid_model", 400)
        end

        model_type = actor_params[:model_type].to_s.classify
        if DiscourseActivityPub::ActorHandler::MODEL_TYPES.exclude?(model_type)
          return render_error("invalid_model", 400)
        end

        if model_type === "Tag"
          @model = model_type.constantize.find_by(name: actor_params[:model_name])
        else
          @model = model_type.constantize.find_by(id: actor_params[:model_id])
        end

        render_error("model_not_found", 404) if @model.blank?
      end

      def render_error(key, status)
        render json:
                 failed_json.merge(errors: [I18n.t("discourse_activity_pub.actor.error.#{key}")]),
               status: status
      end

      def actor_params
        params.require(:actor).permit(
          :model_id,
          :model_type,
          :model_name,
          *DiscourseActivityPubActor::SERIALIZED_FIELDS,
        )
      end
    end
  end
end
