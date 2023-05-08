import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import I18n from "I18n";

createWidget("post-activity-pub-indicator", {
  tagName: "div.post-info.activity-pub",

  title(attrs) {
    let time;
    let key;

    if (attrs.activity_pub_deleted_at) {
      time = moment(attrs.activity_pub_deleted_at);
      key = "deleted";
    } else if (attrs.activity_pub_published_at) {
      time = moment(attrs.activity_pub_published_at);
      key = "published";
    } else {
      let delay_minutes = this.siteSettings.activity_pub_delivery_delay_minutes;
      time = moment(attrs.created_at).add(delay_minutes, "m");
      key = "scheduled";
    }

    return I18n.t(`post.discourse_activity_pub.title.${key}`, { time });
  },

  buildClasses(attrs) {
    return attrs.activity_pub_deleted_at
      ? "deleted"
      : attrs.activity_pub_published_at
      ? "published"
      : "scheduled";
  },

  html() {
    return iconNode("discourse-activity-pub");
  },
});
