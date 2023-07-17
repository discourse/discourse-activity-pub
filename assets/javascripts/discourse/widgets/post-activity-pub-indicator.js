import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { dasherize } from "@ember/string";
import { h } from "virtual-dom";
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

  html(attrs) {
    const visibility = attrs.post.activity_pub_visibility;
    const visibilityHtml = h(
      "div.activity-pub-visibility",
      {
        attributes: {
          title: I18n.t(
            `discourse_activity_pub.visibility.${visibility}.description`
          ),
        },
      },
      visibility === "public" ? iconNode("globe-americas") : iconNode("lock")
    );

    return [iconNode("discourse-activity-pub"), visibilityHtml];
  },
});
