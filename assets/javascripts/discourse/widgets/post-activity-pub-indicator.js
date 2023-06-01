import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { dasherize } from "@ember/string";
import I18n from "I18n";

createWidget("post-activity-pub-indicator", {
  tagName: "div.post-info.activity-pub",

  title(attrs) {
    return I18n.t(`post.discourse_activity_pub.title.${attrs.status}`, {
      time: attrs.time.format("h:mm a, MMM D"),
    });
  },

  buildClasses(attrs) {
    return dasherize(attrs.status);
  },

  html() {
    return iconNode("discourse-activity-pub");
  },
});
