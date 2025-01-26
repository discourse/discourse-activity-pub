import I18n from "I18n";
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

export function activityPubPostStatusText(post) {
  const status = activityPubPostStatus(post);

  let opts = {
    domain: post.activity_pub_domain,
    object_type: post.activity_pub_object_type,
  };

  let time;
  if (status === "deleted") {
    time = moment(post.activity_pub_deleted_at);
  } else if (status === "updated") {
    time = moment(post.activity_pub_updated_at);
  } else if (status.includes("published")) {
    time = moment(post.activity_pub_published_at);
  } else if (status.includes("scheduled")) {
    time = moment(post.activity_pub_scheduled_at);
  }

  if (time) {
    opts.time = time.format("h:mm a, MMM D");
  }

  return I18n.t(`post.discourse_activity_pub.status.${status}`, opts);
}

export function activityPubTopicActors(topic) {
  let result = [];
  if (topic.category) {
    let actor = ActivityPubActor.findByModel(topic.category, "category");
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
