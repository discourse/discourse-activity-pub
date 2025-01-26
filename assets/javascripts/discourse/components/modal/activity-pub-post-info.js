import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { activityPubPostStatusText } from "../../lib/activity-pub-utilities";

export default class ActivityPubPostInfo extends Component {
  @tracked copiedObjectId = false;

  @action
  copyObjectId() {
    clipboardCopy(this.args.model.post.activity_pub_object_id);
    this.copiedObjectId = true;
    setTimeout(() => {
      this.copiedObjectId = false;
    }, 2500);
  }

  get title() {
    return i18n("post.discourse_activity_pub.info.title", {
      post_number: this.args.model.post.post_number,
    });
  }

  get statusText() {
    return activityPubPostStatusText(this.args.model.post);
  }

  get statusIcon() {
    if (this.args.model.status === "not_published") {
      return "far-circle-dot";
    } else {
      return this.args.model.post.activity_pub_local
        ? "arrow-up"
        : "arrow-down";
    }
  }

  get visibilityText() {
    return i18n(
      `discourse_activity_pub.visibility.description.${this.args.model.post.activity_pub_visibility}`,
      {
        object_type: this.args.model.post.activity_pub_object_type,
      }
    );
  }

  get visibilityIcon() {
    return this.args.model.post.activity_pub_visibility === "public"
      ? "earth-americas"
      : "lock";
  }

  get showVisibility() {
    return this.args.model.status !== "not_published";
  }

  get urlText() {
    return i18n("post.discourse_activity_pub.info.url", {
      object_type: this.args.model.post.activity_pub_object_type,
      domain: this.args.model.post.activity_pub_domain,
    });
  }

  get showUrl() {
    return (
      !this.args.model.post.activity_pub_local &&
      this.args.model.post.activity_pub_url
    );
  }

  get showObjectId() {
    return this.args.model.post.activity_pub_object_id;
  }

  get copyObjectIdTitle() {
    return I18n.t("post.discourse_activity_pub.info.copy_uri.title", {
      object_type: this.args.model.post.activity_pub_object_type,
    });
  }

  get copyObjectIdLabel() {
    return I18n.t("post.discourse_activity_pub.info.copy_uri.label");
  }

  get showDelivered() {
    return !!this.args.model.post.activity_pub_delivered_at;
  }

  get deliveredText() {
    let opts = {
      object_type: this.args.model.post.activity_pub_object_type,
    };
    if (this.args.model.post.activity_pub_delivered_at) {
      opts.time = moment(this.args.model.post.activity_pub_delivered_at).format(
        "h:mm a, MMM D"
      );
    }
    return I18n.t("post.discourse_activity_pub.status.delivered", opts);
  }
}
