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
    return `<img loading='lazy' alt='' width='${size}' height='${size}' src='${url}' title='${title}'>`;
  } else {
    return "";
  }
}

registerRawHelper("activityPubActorImage", activityPubActorImage);

export default function activityPubActorImage(actor, params) {
  return htmlSafe(renderActivityPubActorImage.call(this, actor, params));
}
