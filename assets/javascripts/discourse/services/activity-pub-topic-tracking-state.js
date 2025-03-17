import Service, { service } from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { bind } from "discourse/lib/decorators";

const trackedAttributes = [
  "activity_pub_published",
  "activity_pub_published_post_count",
  "activity_pub_total_post_count",
  "activity_pub_scheduled_at",
  "activity_pub_published_at",
  "activity_pub_deleted_at",
  "activity_pub_delivered_at",
];

export default class ActivityPubTopicTrackingState extends Service {
  @service appEvents;

  attributes = new TrackedMap();
  statuses = new TrackedMap();

  init() {
    super.init(...arguments);
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  }

  getStatus(topicId) {
    const status = this.statuses.get(topicId);
    return status || "not_published";
  }

  getAttributes(topicId) {
    const attributes = this.attributes.get(topicId);
    return attributes || {};
  }

  @bind
  update(model) {
    const oldAttributes = this.getAttributes(model.id);
    const newAttributes = {};
    trackedAttributes.forEach((attr) => {
      if (Object.hasOwn(model, attr)) {
        newAttributes[attr] = model[attr];
      }
    });
    const attributes = Object.assign({}, oldAttributes, newAttributes);

    // We don't track activity_pub_local as it won't change, but we still need it here.
    if (model.activity_pub_local !== undefined) {
      attributes.activity_pub_local = model.activity_pub_local;
    }
    this.attributes.set(model.id, attributes);

    let status;
    if (attributes.activity_pub_deleted_at) {
      status = "deleted";
    } else if (attributes.activity_pub_published_at) {
      status = attributes.activity_pub_local ? "published" : "published_remote";
    } else if (attributes.activity_pub_scheduled_at) {
      status = moment().isAfter(moment(attributes.activity_pub_scheduled_at))
        ? "scheduled_past"
        : "scheduled";
    } else {
      status = "not_published";
    }
    this.statuses.set(model.id, status);
  }

  @bind
  handleMessage(data) {
    if (data.model.type === "topic") {
      Object.keys(data.model).forEach((attr) => {
        if (data.model[attr] === undefined) {
          delete data.model[attr];
        }
      });
      this.update(data.model);
    }
  }
}
