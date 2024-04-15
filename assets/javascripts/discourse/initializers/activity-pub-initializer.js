import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";

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
      api.includePostAttributes(
        "activity_pub_updated_at",
        "activity_pub_updated_at"
      );
      api.includePostAttributes(
        "activity_pub_visibility",
        "activity_pub_visibility"
      );
      api.includePostAttributes("activity_pub_local", "activity_pub_local");
      api.includePostAttributes("activity_pub_url", "activity_pub_url");
      api.includePostAttributes(
        "activity_pub_object_type",
        "activity_pub_object_type"
      );
      api.includePostAttributes("activity_pub_domain", "activity_pub_domain");
      api.includePostAttributes(
        "activity_pub_first_post",
        "activity_pub_first_post"
      );
      api.includePostAttributes(
        "activity_pub_is_first_post",
        "activity_pub_is_first_post"
      );
      api.includePostAttributes(
        "activity_pub_object_id",
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
            let time;
            let state;

            if (attrs.activity_pub_deleted_at) {
              time = moment(attrs.activity_pub_deleted_at);
              state = "deleted";
            } else if (attrs.activity_pub_updated_at) {
              time = moment(attrs.activity_pub_updated_at);
              state = "updated";
            } else if (attrs.activity_pub_published_at) {
              time = moment(attrs.activity_pub_published_at);
              state = attrs.activity_pub_local
                ? "published"
                : "published_remote";
            } else if (attrs.activity_pub_scheduled_at) {
              time = moment(attrs.activity_pub_scheduled_at);
              state = moment().isAfter(moment(time))
                ? "scheduled_past"
                : "scheduled";
            } else {
              state = "not_published";
            }

            if (state) {
              let replyToTabIndex = postStatuses.findIndex((postStatus) => {
                return postStatus.name === "reply-to-tab";
              });
              postStatuses.splice(
                replyToTabIndex !== -1 ? replyToTabIndex + 1 : 0,
                0,
                this.attach("post-activity-pub-indicator", {
                  post: attrs,
                  time,
                  state,
                })
              );
            }
          }
          result[result.length - 1].children = postStatuses;
          return result;
        },
      });

      if (api.addPostAdminMenuButton) {
        api.addPostAdminMenuButton((attrs) => {
          if (!attrs.activity_pub_enabled) {
            return;
          }

          const canSchedule =
            currentUser?.staff &&
            attrs.activity_pub_first_post &&
            attrs.activity_pub_is_first_post &&
            !attrs.activity_pub_published_at;

          if (canSchedule) {
            const scheduled = !!attrs.activity_pub_scheduled_at;
            const type = scheduled ? "unschedule" : "schedule";
            return {
              secondaryAction: "closeAdminMenu",
              icon: "discourse-activity-pub",
              className: `activity-pub-${type}`,
              title: `post.discourse_activity_pub.${type}.title`,
              label: `post.discourse_activity_pub.${type}.label`,
              position: "second-last-hidden",
              action: async (post) => {
                if (scheduled) {
                  ajax(`/ap/post/schedule/${post.id}`, {
                    type: "DELETE",
                  }).catch(popupAjaxError);
                } else {
                  ajax(`/ap/post/schedule/${post.id}`, {
                    type: "POST",
                  }).catch(popupAjaxError);
                }
              },
            };
          }
        });
      } else {
        // TODO: remove support for older Discourse versions in December 2023
        api.reopenWidget("post-admin-menu", {
          pluginId: "discourse-activity-pub",

          html(attrs) {
            let result = this._super(attrs);

            if (attrs.activity_pub_enabled) {
              const buttons = result.children.filter(
                (widget) => widget.attrs.action !== "changePostOwner"
              );
              const canSchedule =
                currentUser?.staff &&
                attrs.activity_pub_first_post &&
                attrs.activity_pub_is_first_post &&
                !attrs.activity_pub_published_at;

              if (canSchedule) {
                const scheduled = !!attrs.activity_pub_scheduled_at;
                const type = scheduled ? "unschedule" : "schedule";
                const button = {
                  action: `${type}ActivityPublication`,
                  secondaryAction: "closeAdminMenu",
                  icon: "discourse-activity-pub",
                  className: `activity-pub-${type}`,
                  title: `post.discourse_activity_pub.${type}.title`,
                  label: `post.discourse_activity_pub.${type}.label`,
                  position: "second-last-hidden",
                };
                buttons.push(this.attach("post-admin-menu-button", button));
              }
              result.children = buttons;
            }
            return result;
          },

          scheduleActivityPublication() {
            ajax(`/ap/post/schedule/${this.attrs.id}`, {
              type: "POST",
            }).catch(popupAjaxError);
          },

          unscheduleActivityPublication() {
            ajax(`/ap/post/schedule/${this.attrs.id}`, {
              type: "DELETE",
            }).catch(popupAjaxError);
          },
        });
      }

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
          const postStream = this.get("model.postStream");

          if (data.model.type === "post" && postStream) {
            let stateProps = {
              activity_pub_scheduled_at: data.model.scheduled_at,
              activity_pub_published_at: data.model.published_at,
              activity_pub_deleted_at: data.model.deleted_at,
              activity_pub_updated_at: data.model.updated_at,
            };
            postStream
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
