import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import {
  activityPubPostStatusText,
  activityPubTopicActors,
} from "../../lib/activity-pub-utilities";

export default class ActivityPubPostAdmin extends Component {
  @service siteSettings;
  @tracked status;

  constructor() {
    super(...arguments);

    let status = "unpublished";
    if (this.post.activity_pub_published_at) {
      status = "published";
    } else if (this.post.activity_pub_scheduled_at) {
      status = "scheduled";
    }
    this.status = status;
  }

  get title() {
    return I18n.t("post.discourse_activity_pub.admin.title", {
      post_number: this.post.post_number,
    });
  }

  get post() {
    return this.args.model.post;
  }

  get postStatusText() {
    return activityPubPostStatusText(this.post);
  }

  get actors() {
    return activityPubTopicActors(this.post.topic);
  }

  get noFollowers() {
    return (
      this.actors.reduce(
        (total, actor) => (actor.follower_count || 0) + total,
        0
      ) === 0
    );
  }

  get showDeliver() {
    return this.status === "published" && !this.noFollowers;
  }

  get showPublish() {
    return !["published", "scheduled"].includes(this.status);
  }

  get showSchedule() {
    return ["unpublished", "scheduled"].includes(this.status);
  }

  get scheduleAction() {
    return this.status === "scheduled" ? "unschedule" : "schedule";
  }

  get scheduleDescription() {
    const args = {};
    if (this.scheduleAction === "schedule") {
      args.minutes = this.siteSettings.activity_pub_delivery_delay_minutes;
    }
    let i18nKey = "description";
    if (this.noFollowers) {
      i18nKey = "no_followers";
    }
    return I18n.t(
      `post.discourse_activity_pub.${this.scheduleAction}.${i18nKey}`,
      args
    );
  }

  get scheduleLabel() {
    return I18n.t(`post.discourse_activity_pub.${this.scheduleAction}.label`);
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
    }).catch(popupAjaxError);
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
}
