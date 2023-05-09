import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";
import { Promise } from "rsvp";

export default {
  name: "activity-pub",
  initialize(container) {
    const site = container.lookup("service:site");

    withPluginApi("1.6.0", (api) => {
      const currentUser = api.getCurrentUser();

      api.includePostAttributes("activity_pub_enabled", "activity_pub_enabled");
      api.includePostAttributes(
        "activity_pub_scheduled_at",
        "activity_pub_scheduled_at"
      );
      api.includePostAttributes(
        "activity_pub_published_at",
        "activity_pub_published_at"
      );
      api.includePostAttributes(
        "activity_pub_deleted_at",
        "activity_pub_deleted_at"
      );

      // TODO (future): PR discourse/discourse to add post infos via api
      api.reopenWidget("post-meta-data", {
        html(attrs) {
          const result = this._super(attrs);
          let postStatuses = result[result.length - 1].children;
          postStatuses = postStatuses.filter(
            (n) => n.name !== "post-activity-pub-indicator"
          );
          if (
            site.activity_pub_enabled &&
            attrs.activity_pub_enabled &&
            currentUser?.staff
          ) {
            let time;
            let status;

            if (attrs.activity_pub_deleted_at) {
              time = moment(attrs.activity_pub_deleted_at);
              status = "deleted";
            } else if (attrs.activity_pub_published_at) {
              time = moment(attrs.activity_pub_published_at);
              status = "published";
            } else if (attrs.activity_pub_scheduled_at) {
              time = moment(attrs.activity_pub_scheduled_at);
              status = moment().isAfter(moment(time))
                ? "scheduled_past"
                : "scheduled";
            }

            if (time && status) {
              postStatuses.unshift(
                this.attach("post-activity-pub-indicator", {
                  post: attrs,
                  time,
                  status,
                })
              );
            }
          }
          result[result.length - 1].children = postStatuses;
          return result;
        },
      });

      api.modifyClass("model:post-stream", {
        pluginId: "discourse-activity-pub",

        triggerActivityPubStateChange(postId, stateProps) {
          const resolved = Promise.resolve();
          resolved.then(() => {
            const post = this.findLoadedPost(postId);
            if (post) {
              post.setProperties(stateProps);
              this.storePost(post);
            }
          });
          return resolved;
        },
      });

      api.modifyClass("controller:topic", {
        pluginId: "discourse-activity-pub",

        @bind
        handleActivityPubMessage(data) {
          if (data.model.type === "post") {
            let stateProps = {
              activity_pub_scheduled_at: data.model.scheduled_at,
              activity_pub_published_at: data.model.published_at,
              activity_pub_deleted_at: data.model.deleted_at,
            };
            this.get("model.postStream")
              .triggerActivityPubStateChange(data.model.id, stateProps)
              .then(() =>
                this.appEvents.trigger("post-stream:refresh", {
                  id: data.model.id,
                })
              );
          }
        },

        subscribe() {
          this._super();
          this.messageBus.subscribe(
            "/activity-pub",
            this.handleActivityPubMessage
          );
        },

        unsubscribe() {
          this._super();
          if (!this.get("model.id")) {
            return;
          }
          this.messageBus.subscribe(
            "/activity-pub",
            this.handleActivityPubMessage
          );
        },
      });
    });
  },
};
