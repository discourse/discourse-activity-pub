import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import I18n from "I18n";

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
    return I18n.t("post.discourse_activity_pub.info.title", {
      post_number: this.args.model.post.post_number,
    });
  }

  get stateText() {
    let opts = {
      domain: this.args.model.post.activity_pub_domain,
      object_type: this.args.model.post.activity_pub_object_type,
    };
    if (this.args.model.time) {
      opts.time = this.args.model.time.format("h:mm a, MMM D");
    }
    return I18n.t(
      `post.discourse_activity_pub.title.${this.args.model.state}`,
      opts
    );
  }

  get stateIcon() {
    if (this.args.model.state === "not_published") {
      return "far-dot-circle";
    } else {
      return this.args.model.post.activity_pub_local
        ? "arrow-up"
        : "arrow-down";
    }
  }

  get visibilityText() {
    return I18n.t(
      `discourse_activity_pub.visibility.description.${this.args.model.post.activity_pub_visibility}`,
      {
        object_type: this.args.model.post.activity_pub_object_type,
      }
    );
  }

  get visibilityIcon() {
    return this.args.model.post.activity_pub_visibility === "public"
      ? "globe-americas"
      : "lock";
  }

  get showVisibility() {
    return this.args.model.state !== "not_published";
  }

  get urlText() {
    return I18n.t("post.discourse_activity_pub.info.url", {
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
    return this.args.model.post.activity_pub_local;
  }
}
