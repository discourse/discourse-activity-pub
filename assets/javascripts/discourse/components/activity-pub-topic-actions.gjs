import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { activityPubTopicActors } from "../lib/activity-pub-utilities";

export default class ActivityPubTopicActions extends Component {
  @service appEvents;
  @tracked status;

  constructor() {
    super(...arguments);

    this.topic = EmberObject.create(this.args.topic);
    this.appEvents.on("activity-pub:topic-updated", this, "topicUpdated");

    let status = "unpublished";
    if (this.topic.activity_pub_scheduled_at) {
      status = "scheduled";
    } else if (
      this.topic.activity_pub_published_post_count ===
      this.topic.activity_pub_total_post_count
    ) {
      status = "published";
    }
    this.status = status;
  }

  topicUpdated(topicId, topicProps) {
    if (this.topic.id === topicId) {
      this.topic.setProperties(topicProps);
    }
  }

  get actors() {
    return activityPubTopicActors(this.topic);
  }

  get actorsString() {
    return this.actors
      .map(
        (actor) => `<span class="activity-pub-handle">${actor.handle}</span>`
      )
      .join(", ");
  }

  get publishDisabled() {
    return this.status !== "unpublished";
  }

  get publishDescription() {
    return i18n(
      `topic.discourse_activity_pub.publish.description.${this.status}`,
      {
        count:
          this.topic.activity_pub_total_post_count -
          this.topic.activity_pub_published_post_count,
        topic_id: this.topic.id,
        actors: this.actorsString,
      }
    );
  }

  get showPublish() {
    return this.topic.activity_pub_total_post_count > 1;
  }

  @action
  publish() {
    ajax(`/ap/topic/publish/${this.topic.id}`, {
      type: "POST",
    })
      .then((result) => {
        if (result.success) {
          this.status = "published";
        }
      })
      .catch(popupAjaxError);
  }

  <template>
    {{#if this.showPublish}}
      <div class="activity-pub-topic-actions">
        <div class="action publish-all">
          <div class="action-button">
            <DButton
              @label="topic.discourse_activity_pub.publish.label"
              @action={{this.publish}}
              @disabled={{this.publishDisabled}}
              class="publish"
            />
          </div>
          <div class="action-description">
            {{htmlSafe this.publishDescription}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
