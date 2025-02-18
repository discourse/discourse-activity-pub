import { AUTO_GROUPS } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../models/activity-pub-actor";

function getStatusDatetimeFormat(infoStatus = false) {
  return infoStatus
    ? i18n("dates.long_with_year")
    : i18n("dates.time_short_day");
}

export function buildHandle({ actor, model, site }) {
  if ((!actor && !model) || (model && !site)) {
    return undefined;
  } else {
    const username = actor ? actor.username : model.activity_pub_username;
    const domain = actor ? actor.domain : site.activity_pub_host;
    return `@${username}@${domain}`;
  }
}

export function showStatusToUser(user, siteSettings) {
  if (!siteSettings) {
    return false;
  }
  const groupIds = siteSettings.activity_pub_post_status_visibility_groups
    .split("|")
    .map(Number);
  if (groupIds.includes(AUTO_GROUPS.everyone.id)) {
    return true;
  }
  if (!user) {
    return false;
  }
  return user.groups.some((group) => groupIds.includes(group.id));
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

export function activityPubTopicStatus(topic) {
  let status;

  if (topic.activity_pub_deleted_at) {
    status = "deleted";
  } else if (topic.activity_pub_published_at) {
    status = topic.activity_pub_local ? "published" : "published_remote";
  } else if (topic.activity_pub_scheduled_at) {
    status = moment().isAfter(moment(topic.activity_pub_scheduled_at))
      ? "scheduled_past"
      : "scheduled";
  } else {
    status = "not_published";
  }

  return status;
}

export function activityPubTopicStatusText(topic, opts = {}) {
  const status = activityPubTopicStatus(topic);

  let i18nKey = opts.infoStatus ? "info_status" : "status";
  let i18nOpts = {
    actor: topic.activity_pub_actor.handle,
  };

  let datetime;
  if (status === "deleted") {
    datetime = topic.activity_pub_deleted_at;
  } else if (status === "published") {
    datetime = topic.activity_pub_published_at;
  } else if (status === "published_remote") {
    datetime = topic.activity_pub_published_at;
  } else if (status.includes("scheduled")) {
    datetime = topic.activity_pub_scheduled_at;
  }

  if (datetime) {
    i18nOpts.datetime = moment(datetime).format(
      getStatusDatetimeFormat(opts.infoStatus)
    );
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
