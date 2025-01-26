import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import { activityPubTopicActors } from "../../lib/activity-pub-utilities";

export default class ActivityPubTopicAdmin extends Component {
  @tracked status;

  constructor() {
    super(...arguments);

    let status = "none_published";
    if (this.topic.activity_pub_published) {
      status = "published";
    } else if (this.topic.activity_pub_first_post_scheduled) {
      status = "scheduled";
    } else if (this.topic.activity_pub_published_post_count > 0) {
      status = "some_published";
    }
    this.status = status;
  }

  get title() {
    return I18n.t("topic.discourse_activity_pub.admin.title", {
      topic_id: this.topic.id,
    });
  }

  get topic() {
    return this.args.model.topic;
  }

  get actors() {
    return activityPubTopicActors(this.topic);
  }

  get statusText() {
    return I18n.t(`topic.discourse_activity_pub.status.${this.status}`, {
      total: this.topic.activity_pub_total_post_count,
      count: this.topic.activity_pub_published_post_count,
    });
  }

  get publishLabel() {
    let i18nKey = "label";
    if (this.topic.activity_pub_first_post_scheduled) {
      i18nKey = "first_post_scheduled";
    }
    return I18n.t(`topic.discourse_activity_pub.publish.${i18nKey}`);
  }

  get canPublish() {
    return (
      this.topic.activity_pub_full_topic &&
      !["scheduled", "published"].includes(this.status)
    );
  }

  @action
  publish() {
    ajax(`/ap/topic/publish/${this.topic.id}`, {
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
