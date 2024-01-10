import { dasherize } from "@ember/string";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import ActivityPubPostInfoModal from "../components/modal/activity-pub-post-info";

createWidget("post-activity-pub-indicator", {
  tagName: "div.post-info.activity-pub",
  services: ["modal"],

  title(attrs) {
    let opts = {
      domain: attrs.post.activity_pub_domain,
      object_type: attrs.post.activity_pub_object_type,
    };
    if (attrs.time) {
      opts.time = attrs.time.format("h:mm a, MMM D");
    }
    return I18n.t(`post.discourse_activity_pub.title.${attrs.state}`, opts);
  },

  buildClasses(attrs) {
    let placeClass = attrs.post.activity_pub_local ? "local" : "remote";
    return [dasherize(attrs.state), placeClass];
  },

  html(attrs) {
    let iconName =
      attrs.state === "not_published"
        ? "discourse-activity-pub-slash"
        : "discourse-activity-pub";
    return iconNode(iconName);
  },

  click() {
    this.modal.show(ActivityPubPostInfoModal, { model: this.attrs });
  },
});
