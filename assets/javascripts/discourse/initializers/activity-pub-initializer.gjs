import { service } from "@ember/service";
import { hbs } from "ember-cli-htmlbars";
import { Promise } from "rsvp";
import { bind } from "discourse/lib/decorators";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { i18n } from "discourse-i18n";
import ActivityPubPostStatus from "../components/activity-pub-post-status";
import ActivityPubTopicMap from "../components/activity-pub-topic-map";
import ActivityPubPostModal from "../components/modal/activity-pub-post";
import ActivityPubTopicModal from "../components/modal/activity-pub-topic";
import {
  activityPubPostStatus,
  showStatusToUser,
} from "../lib/activity-pub-utilities";

export default {
  name: "activity-pub",
  initialize(container) {
    const modal = container.lookup("service:modal");

    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();

      customizePost(api, container);

      api.serializeOnCreate("activity_pub_visibility");

      api.addTopicAdminMenuButton((topic) => {
        if (topic.activity_pub_enabled && currentUser?.staff) {
          const firstPost = topic
            .get("postStream.posts")
            .find((item) => item.post_number === 1);
          return {
            icon: "discourse-activity-pub",
            className: "show-activity-pub-topic-admin",
            label: "discourse_activity_pub.model.menu",
            action: async () => {
              modal.show(ActivityPubTopicModal, {
                model: {
                  topic,
                  firstPost,
                },
              });
            },
          };
        }
      });

      api.modifyClass("route:topic", {
        pluginId: "discourse-activity-pub",
        apTopicTrackingState: service("activity-pub-topic-tracking-state"),

        setupController(controller, model) {
          this._super(controller, model);
          this.apTopicTrackingState.update(model);
        },
      });

      api.modifyClass(
        "model:post-stream",
        (Superclass) =>
          class extends Superclass {
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
            }
          }
      );

      api.modifyClass(
        "model:topic",
        (Superclass) =>
          class extends Superclass {
            getActivityPubPostActor(postId) {
              const postActors = this.activity_pub_post_actors || [];
              return postActors.find((item) => item.post_id === postId);
            }
          }
      );

      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            @bind
            handleActivityPubPostMessage(data) {
              const topic = this.get("model");
              if (
                !topic ||
                data.model.topic_id !== topic.id ||
                data.model.type !== "post"
              ) {
                return;
              }

              let props = {
                activity_pub_scheduled_at: data.model.scheduled_at,
                activity_pub_published_at: data.model.published_at,
                activity_pub_deleted_at: data.model.deleted_at,
                activity_pub_updated_at: data.model.updated_at,
                activity_pub_delivered_at: data.model.delivered_at,
              };
              topic.postStream
                .triggerActivityPubStateChange(data.model.id, props)
                .then(() =>
                  // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
                  this.appEvents.trigger("post-stream:refresh", {
                    id: data.model.id,
                  })
                );
              this.appEvents.trigger(
                "activity-pub:post-updated",
                data.model.id,
                props
              );
            }

            subscribe() {
              super.subscribe();
              this.messageBus.subscribe(
                "/activity-pub",
                this.handleActivityPubPostMessage
              );
            }

            unsubscribe() {
              super.unsubscribe();
              this.messageBus.unsubscribe(
                "/activity-pub",
                this.handleActivityPubPostMessage
              );
            }
          }
      );

      api.renderInOutlet("topic-map", ActivityPubTopicMap);

      api.addCommunitySectionLink(
        {
          name: "activity-pub-about",
          route: "activityPub.about",
          title: i18n("discourse_activity_pub.about.navigation.title"),
          text: i18n("discourse_activity_pub.about.navigation.label"),
          icon: "discourse-activity-pub",
        },
        true
      );
    });
  },
};

function customizePost(api, container) {
  const currentUser = api.getCurrentUser();
  const modal = container.lookup("service:modal");

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
    "activity_pub_object_id"
  );

  const PostMetadataActivityPubStatus = <template>
    <div class="post-info activity-pub">
      <ActivityPubPostStatus @post={{@post}} />
    </div>
  </template>;

  api.registerValueTransformer(
    "post-meta-data-infos",
    ({ value: metadata, context: { post, metaDataInfoKeys } }) => {
      const site = container.lookup("service:site");
      const siteSettings = container.lookup("service:site-settings");

      if (
        site.activity_pub_enabled &&
        post.activity_pub_enabled &&
        post.post_number !== 1 &&
        showStatusToUser(currentUser, siteSettings)
      ) {
        const status = activityPubPostStatus(post);

        if (status) {
          metadata.add(
            "activity-pub-indicator",
            PostMetadataActivityPubStatus,
            {
              before: metaDataInfoKeys.DATE,
              after: metaDataInfoKeys.REPLY_TO_TAB,
            }
          );
        }
      }
    }
  );

  api.addPostAdminMenuButton((attrs) => {
    if (attrs.activity_pub_enabled && currentUser?.staff && !attrs.firstPost) {
      return {
        secondaryAction: "closeAdminMenu",
        icon: "discourse-activity-pub",
        className: "show-activity-pub-post-admin",
        label: "discourse_activity_pub.model.menu",
        position: "second-last-hidden",
        action: async (post) => {
          modal.show(ActivityPubPostModal, {
            model: {
              post,
            },
          });
        },
      };
    }
  });

  withSilencedDeprecations("discourse.post-stream-widget-overrides", () =>
    customizeWidgetPost(api, container)
  );
}

function customizeWidgetPost(api, container) {
  const currentUser = api.getCurrentUser();
  const site = container.lookup("service:site");
  const siteSettings = container.lookup("service:site-settings");

  api.reopenWidget("post-meta-data", {
    html(attrs) {
      const result = this._super(attrs);
      let postStatuses = result[result.length - 1].children;
      postStatuses = postStatuses.filter(
        (n) => n.renderInto !== "div.post-info.activity-pub"
      );
      if (
        site.activity_pub_enabled &&
        attrs.activity_pub_enabled &&
        attrs.post_number !== 1 &&
        showStatusToUser(currentUser, siteSettings)
      ) {
        const status = activityPubPostStatus(attrs);
        if (status) {
          let replyToTabIndex = postStatuses.findIndex((postStatus) => {
            return postStatus.name === "reply-to-tab";
          });
          const post = this.findAncestorModel();
          postStatuses.splice(
            replyToTabIndex !== -1 ? replyToTabIndex + 1 : 0,
            0,
            new RenderGlimmer(
              this,
              "div.post-info.activity-pub",
              hbs`<ActivityPubPostStatus @post={{@data.post}} />`,
              {
                post,
              }
            )
          );
        }
      }
      result[result.length - 1].children = postStatuses;
      return result;
    },
  });
}
