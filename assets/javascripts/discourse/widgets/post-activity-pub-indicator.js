import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { dasherize } from "@ember/string";
import I18n from "I18n";
import ActivityPubPostInfoModal from "../components/modal/activity-pub-post-info";

createWidget("post-activity-pub-indicator", {
  tagName: "div.post-info.activity-pub",
  services: ["modal"],

  title(attrs) {
    return I18n.t(`post.discourse_activity_pub.title.${attrs.state}`, {
      time: attrs.time.format("h:mm a, MMM D"),
      domain: attrs.post.activity_pub_domain,
      object_type: attrs.post.activity_pub_object_type,
    });
  },

  buildClasses(attrs) {
    let placeClass = attrs.post.activity_pub_local ? "local" : "remote";
    return [dasherize(attrs.state), placeClass];
  },

  html() {
    return iconNode("discourse-activity-pub");
  },

  click() {
    this.modal.show(ActivityPubPostInfoModal, { model: this.attrs });
  },
});
