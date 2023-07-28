import Component from "@glimmer/component";
import I18n from "I18n";

export default class ActivityPubPostInfo extends Component {
  get title() {
    return I18n.t("post.discourse_activity_pub.info.title", {
      post_number: this.args.model.post.post_number,
    });
  }

  get statusText() {
    return I18n.t(
      `post.discourse_activity_pub.title.${this.args.model.status}`,
      {
        time: this.args.model.time.format("h:mm a, MMM D"),
        domain: this.args.model.post.activity_pub_domain,
        object_type: this.args.model.post.activity_pub_object_type,
      }
    );
  }

  get statusIcon() {
    return this.args.model.post.activity_pub_local ? "upload" : "download";
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

  get urlText() {
    return I18n.t("post.discourse_activity_pub.info.url", {
      object_type: this.args.model.post.activity_pub_object_type,
      domain: this.args.model.post.activity_pub_domain,
    });
  }
}
