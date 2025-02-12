import { AUTO_GROUPS } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../models/activity-pub-actor";

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
  if (!user || !siteSettings) {
    return false;
  }
  const groupIds = siteSettings.activity_pub_post_status_visibility_groups
    .split("|")
    .map(Number);
  return user.groups.some(
    (group) =>
      groupIds.includes(AUTO_GROUPS.everyone.id) || groupIds.includes(group.id)
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
  const status = activityPubPostStatus(post);

  let i18nKey;
  let i18nOpts = {};

  if (opts.showObjectType && post.activity_pub_object_type) {
    i18nKey = "object_status";
    i18nOpts.object_type = post.activity_pub_object_type;
  } else {
    i18nKey = "status";
  }

  let time;
  if (status === "deleted") {
    time = moment(post.activity_pub_deleted_at);
  } else if (status === "updated") {
    time = moment(post.activity_pub_updated_at);
  } else if (status === "published") {
    time = moment(post.activity_pub_published_at);
  } else if (status === "published_remote") {
    time = moment(post.activity_pub_published_at);
    i18nOpts.domain = post.activity_pub_domain;
  } else if (status.includes("scheduled")) {
    time = moment(post.activity_pub_scheduled_at);
  }

  if (time) {
    i18nOpts.time = time.format(i18n("dates.long_with_year"));
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

  let i18nKey = "status";
  let i18nOpts = {};

  if (opts.showObjectType) {
    i18nKey = "object_status";
    i18nOpts.object_type = topic.activity_pub_object_type || "Collection";
  }

  let time;
  if (status === "deleted") {
    time = moment(topic.activity_pub_deleted_at);
  } else if (status === "published") {
    time = moment(topic.activity_pub_published_at);
  } else if (status === "published_remote") {
    time = moment(topic.activity_pub_published_at);
    i18nOpts.actor = topic.activity_pub_actor.handle;
  } else if (status.includes("scheduled")) {
    time = moment(topic.activity_pub_scheduled_at);
  }

  if (time) {
    i18nOpts.time = time.format(i18n("dates.long_with_year"));
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
