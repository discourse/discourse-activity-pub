import { dasherize } from "@ember/string";
import { iconNode } from "discourse/lib/icon-library";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import ActivityPubPostInfoModal from "../components/modal/activity-pub-post-info";
import { activityPubPostStatusText } from "../lib/activity-pub-utilities";

createWidget("post-activity-pub-indicator", {
  tagName: "div.post-info.activity-pub",
  services: ["modal"],

  title(attrs) {
    return activityPubPostStatusText(attrs.post);
  },

  buildClasses(attrs) {
    let placeClass = attrs.post.activity_pub_local ? "local" : "remote";
    return [dasherize(attrs.status), placeClass];
  },

  html(attrs) {
    let iconName =
      attrs.status === "not_published"
        ? "discourse-activity-pub-slash"
        : "discourse-activity-pub";
    return iconNode(iconName);
  },

  click() {
    this.modal.show(ActivityPubPostInfoModal, { model: this.attrs });
  },
});
