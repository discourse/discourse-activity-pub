import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse-common/lib/helpers";
import { buildHandle } from "../lib/activity-pub-utilities";

function renderActivityPubActorHandle(actor) {
  if (actor) {
    const handle = buildHandle({ actor });
    return `<a href='${actor.url}' target="_blank" rel="noopener noreferrer">${handle}</a>`;
  }
}

registerRawHelper("activityPubActorHandle", activityPubActorHandle);

export default function activityPubActorHandle(actor) {
  return htmlSafe(renderActivityPubActorHandle.call(this, actor));
}
