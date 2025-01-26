import { Promise } from "rsvp";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "activity-pub",
  initialize(container) {
    const site = container.lookup("service:site");

    withPluginApi("1.6.0", (api) => {
      const currentUser = api.getCurrentUser();
      const modal = api._lookupContainer("service:modal");

      api.addTrackedPostProperties(
        "activity_pub_enabled",
        "activity_pub_scheduled_at",
        "activity_pub_published_at",
        "activity_pub_delivered_at",
        "activity_pub_deleted_at",
        "activity_pub_updated_at",
        "activity_pub_visibility",
        "activity_pub_local",
        "activity_pub_url",
        "activity_pub_object_type",
        "activity_pub_domain",
        "activity_pub_first_post",
        "activity_pub_is_first_post",
        "activity_pub_object_id"
      );
      api.serializeOnCreate("activity_pub_visibility");

      // TODO (future): PR discourse/discourse to add post infos via api
      api.reopenWidget("post-meta-data", {
        showStatusToUser(user) {
          if (!user) {
            return false;
          }
          const groupIds =
            this.siteSettings.activity_pub_post_status_visibility_groups
              .split("|")
              .map(Number);
          return user.groups.some(
            (group) =>
              groupIds.includes(AUTO_GROUPS.everyone.id) ||
              groupIds.includes(group.id)
          );
        },

        html(attrs) {
          const result = this._super(attrs);
          let postStatuses = result[result.length - 1].children;
          postStatuses = postStatuses.filter(
            (n) => n.name !== "post-activity-pub-indicator"
          );
          if (
            site.activity_pub_enabled &&
            attrs.activity_pub_enabled &&
            this.showStatusToUser(this.currentUser)
          ) {
            const status = activityPubPostStatus(attrs);
            if (status) {
              let replyToTabIndex = postStatuses.findIndex((postStatus) => {
                return postStatus.name === "reply-to-tab";
              });
              postStatuses.splice(
                replyToTabIndex !== -1 ? replyToTabIndex + 1 : 0,
                0,
                this.attach("post-activity-pub-indicator", {
                  post: attrs,
                  status,
                })
              );
            }
          }
          result[result.length - 1].children = postStatuses;
          return result;
        },
      });

      api.addPostAdminMenuButton((attrs) => {
        if (
          attrs.activity_pub_enabled &&
          currentUser?.staff &&
          attrs.activity_pub_is_first_post
        ) {
          return {
            secondaryAction: "closeAdminMenu",
            icon: "discourse-activity-pub",
            className: "show-activity-pub-post-admin",
            label: "post.discourse_activity_pub.admin.label",
            position: "second-last-hidden",
            action: async (post) => {
              modal.show(ActivityPubPostAdmin, {
                model: {
                  post,
                },
              });
            },
          };
        }
      });

      api.addTopicAdminMenuButton((topic) => {
        if (topic.activity_pub_enabled && currentUser?.staff) {
          return {
            icon: "discourse-activity-pub",
            className: "show-activity-pub-topic-admin",
            title: "topic.discourse_activity_pub.admin.title",
            label: "topic.discourse_activity_pub.admin.label",
            action: async () => {
              modal.show(ActivityPubTopicAdmin, {
                model: {
                  topic,
                },
              });
            },
          };
        }
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
          const topic = this.get("model");
          const postStream = topic.get("postStream");

          if (data.model.type === "post" && postStream) {
            let stateProps = {
              activity_pub_scheduled_at: data.model.scheduled_at,
              activity_pub_published_at: data.model.published_at,
              activity_pub_deleted_at: data.model.deleted_at,
              activity_pub_updated_at: data.model.updated_at,
              activity_pub_delivered_at: data.model.delivered_at,
            };
            postStream
              .triggerActivityPubStateChange(data.model.id, stateProps)
              .then(() =>
                this.appEvents.trigger("post-stream:refresh", {
                  id: data.model.id,
                })
              );
          }

          if (data.model.type === "topic" && topic) {
            let topicProps = {
              activity_pub_published: data.model.published,
              activity_pub_published_post_count:
                data.model.published_post_count,
              activity_pub_total_post_count: data.model.total_post_count,
              activity_pub_first_post_scheduled:
                data.model.first_post_scheduled,
            };
            topic.setProperties(topicProps);
            postStream.refresh();
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
