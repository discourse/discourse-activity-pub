import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { activityPubTopicActors } from "../lib/activity-pub-utilities";

export default class ActivityPubPostActions extends Component {
  @service("activity-pub-topic-tracking-state") apTopicTrackingState;
  @service siteSettings;
  @service appEvents;

  @tracked status;
  @tracked post;

  constructor() {
    super(...arguments);

    this.post = this.args.post;
    this.appEvents.on("activity-pub:post-updated", this, "postUpdated");

    let status = "unpublished";
    if (this.post.activity_pub_published_at) {
      status = "published";
    } else if (this.post.activity_pub_scheduled_at) {
      status = "scheduled";
    }
    this.status = status;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("activity-pub:post-updated", this, "postUpdated");
  }

  postUpdated(postId, postProps) {
    if (this.post.id === postId) {
      this.post.setProperties(postProps);
    }
  }

  get topicAttributes() {
    return this.apTopicTrackingState.getAttributes(this.post.topic.id);
  }

  get actors() {
    return activityPubTopicActors(this.post.topic);
  }

  get actorsString() {
    return this.actors
      .map(
        (actor) => `<span class="activity-pub-handle">${actor.handle}</span>`
      )
      .join(" ");
  }

  get noFollowers() {
    return (
      this.actors.reduce(
        (total, actor) => (actor.follower_count || 0) + total,
        0
      ) === 0
    );
  }

  get showActions() {
    return this.showDeliver || this.showPublish || this.showSchedule;
  }

  get showDeliver() {
    return ["published", "delivered"].includes(this.status);
  }

  get deliverLabel() {
    return i18n(`post.discourse_activity_pub.actions.deliver.label`, {
      post_number: this.post.post_number,
    });
  }

  get deliverDescription() {
    let args = {
      post_number: this.post.post_number,
    };
    let i18nKey;

    if (this.status === "delivered") {
      i18nKey = "delivered";
    } else if (
      this.post.post_number !== 1 &&
      !this.topicAttributes.activity_pub_delivered_at
    ) {
      i18nKey = "topic_not_delivered";
      args.topic_id = this.post.topic.id;
    } else if (this.noFollowers) {
      i18nKey = "no_followers";
    } else {
      i18nKey = "followers";
    }

    return i18n(
      `post.discourse_activity_pub.actions.deliver.description.${i18nKey}`,
      args
    );
  }

  get deliverDisabled() {
    return (
      this.status === "delivered" ||
      !this.post.activity_pub_published_at ||
      this.noFollowers ||
      (!this.topicAttributes.activity_pub_delivered_at &&
        this.post.post_number !== 1)
    );
  }

  get showPublish() {
    return !["published", "delivered"].includes(this.status);
  }

  get publishLabel() {
    return i18n(`post.discourse_activity_pub.actions.publish.label`, {
      post_number: this.post.post_number,
      actors: this.actorsString,
    });
  }

  get publishDescription() {
    let args = {
      post_number: this.post.post_number,
    };
    let i18nKey;

    if (
      this.post.post_number !== 1 &&
      !this.topicAttributes.activity_pub_published_at
    ) {
      i18nKey = "topic_not_published";
      args.topic_id = this.post.topic.id;
    } else if (this.post.activity_pub_scheduled_at) {
      i18nKey = "post_is_scheduled";
    } else if (this.noFollowers) {
      i18nKey = "no_followers";
    } else {
      args.actors = this.actorsString;
      i18nKey = "followers";
    }

    return i18n(
      `post.discourse_activity_pub.actions.publish.description.${i18nKey}`,
      args
    );
  }

  get publishDisabled() {
    return (
      !!this.post.activity_pub_published_at ||
      !!this.post.activity_pub_scheduled_at ||
      (!this.topicAttributes.activity_pub_published_at &&
        this.post.post_number !== 1)
    );
  }

  get showSchedule() {
    return (
      ["unpublished", "scheduled"].includes(this.status) &&
      this.post.post_number === 1
    );
  }

  get scheduleAction() {
    return this.status === "scheduled" ? "unschedule" : "schedule";
  }

  get scheduleLabel() {
    return i18n(
      `post.discourse_activity_pub.actions.${this.scheduleAction}.label`,
      {
        post_number: this.post.post_number,
      }
    );
  }

  get scheduleDescription() {
    let args = {
      post_number: this.post.post_number,
    };
    let i18nKey = "description";

    if (this.scheduleAction === "schedule") {
      args.minutes = this.siteSettings.activity_pub_delivery_delay_minutes;

      if (this.noFollowers) {
        i18nKey += ".no_followers";
      } else {
        args.actors = this.actorsString;
        i18nKey += ".followers";
      }
    }

    return i18n(
      `post.discourse_activity_pub.actions.${this.scheduleAction}.${i18nKey}`,
      args
    );
  }

  @action
  unschedule() {
    ajax(`/ap/post/schedule/${this.post.id}`, {
      type: "DELETE",
    })
      .then((result) => {
        if (result.success) {
          this.status = "unpublished";
        }
      })
      .catch(popupAjaxError);
  }

  @action
  schedule() {
    ajax(`/ap/post/schedule/${this.post.id}`, {
      type: "POST",
    })
      .then((result) => {
        if (result.success) {
          this.status = "scheduled";
        }
      })
      .catch(popupAjaxError);
  }

  @action
  deliver() {
    ajax(`/ap/post/deliver/${this.post.id}`, {
      type: "POST",
    })
      .then((result) => {
        if (result.success) {
          this.status = "delivered";
        }
      })
      .catch(popupAjaxError);
  }

  @action
  publish() {
    ajax(`/ap/post/publish/${this.post.id}`, {
      type: "POST",
    })
      .then((result) => {
        if (result.success) {
          this.status = "published";
        }
      })
      .catch(popupAjaxError);
  }

  <template>
    {{#if this.showActions}}
      <div class="activity-pub-post-actions">
        {{#if this.showDeliver}}
          <div class="action deliver">
            <div class="action-button">
              <DButton
                @translatedLabel={{this.deliverLabel}}
                @action={{this.deliver}}
                @disabled={{this.deliverDisabled}}
                class="deliver"
              />
            </div>
            <div class="action-description">
              {{htmlSafe this.deliverDescription}}
            </div>
          </div>
        {{/if}}
        {{#if this.showPublish}}
          <div class="action publish">
            <div class="action-button">
              <DButton
                @translatedLabel={{this.publishLabel}}
                @action={{this.publish}}
                @disabled={{this.publishDisabled}}
                class="publish"
              />
            </div>
            <div class="action-description">
              {{htmlSafe this.publishDescription}}
            </div>
          </div>
        {{/if}}
        {{#if this.showSchedule}}
          <div class="action schedule">
            <div class="action-button">
              <DButton
                @translatedLabel={{this.scheduleLabel}}
                @action={{action this.scheduleAction}}
                @disabled={{this.noFollowers}}
                class={{this.scheduleAction}}
              />
            </div>
            <div class="action-description">
              {{htmlSafe this.scheduleDescription}}
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
