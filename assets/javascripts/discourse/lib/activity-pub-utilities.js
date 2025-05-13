import { AUTO_GROUPS } from "discourse/lib/constants";
import Site from "discourse/models/site";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../models/activity-pub-actor";

function getStatusDatetimeFormat(infoStatus = false) {
  return infoStatus
    ? i18n("dates.long_with_year")
    : i18n("dates.time_short_day");
}

export function buildHandle({ actor, model, site }) {
  if (actor) {
    return `@${actor.username}@${actor.domain}`;
  } else if (model && site) {
    return `@${model.activity_pub_username}@${site.activity_pub_host}`;
  }
}

export function showStatusToUser(user, siteSettings) {
  const groupIds = siteSettings.activity_pub_post_status_visibility_groups
    .split("|")
    .map(Number);

  return (
    groupIds.includes(AUTO_GROUPS.everyone.id) ||
    user?.groups.some((group) => groupIds.includes(group.id))
  );
}

export function activityPubPostStatus(post) {
  let status;

  if (post.activity_pub_deleted_at) {
    status = "deleted";
  } else if (post.activity_pub_updated_at) {
    status = "updated";
  } else if (post.activity_pub_published_at) {
    status = post.activity_pub_local ? "published" : "published_remote";
  } else if (post.activity_pub_scheduled_at) {
    status = moment().isAfter(moment(post.activity_pub_scheduled_at))
      ? "scheduled_past"
      : "scheduled";
  } else {
    status = "not_published";
  }

  return status;
}

export function activityPubPostStatusText(post, opts = {}) {
  const status = opts.status || activityPubPostStatus(post);

  let i18nKey = opts.infoStatus ? "info_status" : "status";
  let i18nOpts = {
    actor: opts.postActor?.actor.handle,
  };

  let datetime;
  if (status === "delivered") {
    datetime = post.activity_pub_delivered_at;
  } else if (status === "deleted") {
    datetime = post.activity_pub_deleted_at;
  } else if (status === "updated") {
    datetime = post.activity_pub_updated_at;
  } else if (status === "published") {
    datetime = post.activity_pub_published_at;
  } else if (status === "published_remote") {
    datetime = post.activity_pub_published_at;
  } else if (status.includes("scheduled")) {
    datetime = post.activity_pub_scheduled_at;
  }

  if (datetime) {
    i18nOpts.datetime = moment(datetime).format(
      getStatusDatetimeFormat(opts.infoStatus)
    );
  }

  return i18n(`post.discourse_activity_pub.${i18nKey}.${status}`, i18nOpts);
}

export function activityPubTopicStatusText({
  actor,
  attributes,
  status,
  info,
}) {
  let i18nKey = info ? "info_status" : "status";
  let i18nOpts = { actor };

  let datetime;
  if (status === "deleted") {
    datetime = attributes.activity_pub_deleted_at;
  } else if (status === "published") {
    datetime = attributes.activity_pub_published_at;
  } else if (status === "published_remote") {
    datetime = attributes.activity_pub_published_at;
  } else if (status.includes("scheduled")) {
    datetime = attributes.activity_pub_scheduled_at;
  }

  if (datetime) {
    i18nOpts.datetime = moment(datetime).format(getStatusDatetimeFormat(info));
  }

  return i18n(`topic.discourse_activity_pub.${i18nKey}.${status}`, i18nOpts);
}

export function activityPubTopicActors(topic) {
  let result = [];
  if (topic.category_id) {
    let actor = ActivityPubActor.findByModel(
      { id: topic.category_id },
      "category"
    );
    if (actor) {
      result.push(actor);
    }
  }
  if (topic.tags) {
    topic.tags.forEach((tag) => {
      let actor = ActivityPubActor.findByModel(tag, "tag");
      if (actor) {
        result.push(actor);
      }
    });
  }
  return result;
}

export function updateSiteActor(newActor) {
  if (!newActor || !newActor.model_type) {
    return;
  }
  const actors = Site.currentProp("activity_pub_actors");
  if (!actors) {
    return;
  }

  const modelType = newActor.model_type.toLowerCase();
  const existingActor = actors[modelType].find(
    (actor) => actor.id === newActor.id
  );

  if (existingActor) {
    actors[modelType].splice(
      actors[modelType].indexOf(existingActor),
      1,
      newActor
    );
  } else {
    actors[modelType].push(newActor);
  }

  Site.currentProp("activity_pub_actors", actors);
}
