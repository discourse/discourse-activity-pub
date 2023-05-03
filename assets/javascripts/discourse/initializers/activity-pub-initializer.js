import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";
import { Promise } from "rsvp";

export default {
  name: "activity-pub",
  initialize() {
    withPluginApi("1.6.0", (api) => {
      const currentUser = api.getCurrentUser();

      api.includePostAttributes("activity_pub_enabled", "activity_pub_enabled");
      api.includePostAttributes(
        "activity_pub_published_at",
        "activity_pub_published_at"
      );

      api.addPostTransformCallback((attrs) => {
        if (
          attrs.isDeleted &&
          attrs.activity_pub_enabled &&
          attrs.activity_pub_published_at
        ) {
          // TODO (improve?). currently necessary because
          // discourse/models/topic#destroy hardcodes
          // "details.can_recover": true in its callback.
          attrs.canRecoverTopic = false;
        }
      });

      api.addPostMenuButton("activity-pub-restore", (attrs) => {
        if (
          attrs.isDeleted &&
          attrs.activity_pub_enabled &&
          attrs.activity_pub_published_at
        ) {
          return {
            icon: "undo",
            title: "post.discourse_activity_pub.restore.not_supported",
            position: "second-last-hidden",
            disabled: true,
          };
        }
      });

      // TODO (future): PR discourse/discourse to add post infos via api
      api.reopenWidget("post-meta-data", {
        html(attrs) {
          const result = this._super(attrs);

          if (attrs.activity_pub_enabled && currentUser?.admin) {
            result[result.length - 1].children.unshift(
              this.attach("post-activity-pub-indicator", attrs)
            );
          }

          return result;
        },
      });

      api.modifyClass("model:post-stream", {
        pluginId: "discourse-activity-pub",

        triggerActivityPubPublished(postId, publishedAt) {
          const resolved = Promise.resolve();
          resolved.then(() => {
            const post = this.findLoadedPost(postId);
            if (post) {
              post.set("activity_pub_published_at", publishedAt);
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
            this.get("model.postStream")
              .triggerActivityPubPublished(
                data.model.id,
                data.model.published_at
              )
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
