import { htmlSafe } from "@ember/template";
import { translateSize } from "discourse-common/lib/avatar-utils";
import { registerRawHelper } from "discourse-common/lib/helpers";
import { buildHandle } from "../lib/activity-pub-utilities";

function renderActivityPubActorImage(actor, opts) {
  opts = opts || {};

  if (actor) {
    const size = translateSize(opts.size);
    const url = actor.icon_url || "/images/avatar.png";
    const title = buildHandle({ actor });
    const img = `<img loading='lazy' alt='' width='${size}' height='${size}' src='${url}' title='${title}'>`;
    return `<div class="activity-pub-actor-image">${img}</div>`;
  } else {
    return "";
  }
}

registerRawHelper("activityPubActorImage", activityPubActorImage);

export default function activityPubActorImage(actor, params) {
  return htmlSafe(renderActivityPubActorImage.call(this, actor, params));
}
