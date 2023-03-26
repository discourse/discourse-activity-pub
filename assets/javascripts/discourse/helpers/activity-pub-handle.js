import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound("activity-pub-handle", function (actor) {
  if (!actor || !actor.activity_pub_username) {
    return "";
  }
  const handle = `${actor.activity_pub_username}@${window.location.hostname}`;
  return htmlSafe(`<span class="activity-pub-handle">${handle}</span>`);
});
