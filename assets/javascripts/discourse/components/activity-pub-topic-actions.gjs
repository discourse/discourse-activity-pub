import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { activityPubTopicActors } from "../lib/activity-pub-utilities";

export default class ActivityPubTopicActions extends Component {
  @service("activity-pub-topic-tracking-state") apTopicTrackingState;

  get topic() {
    return this.args.topic;
  }

  get attributes() {
    return this.apTopicTrackingState.getAttributes(this.topic.id);
  }

  get status() {
    return this.apTopicTrackingState.getStatus(this.topic.id);
  }

  get actors() {
    return activityPubTopicActors(this.topic);
  }

  get actorsString() {
    return this.actors
      .map(
        (actor) => `<span class="activity-pub-handle">${actor.handle}</span>`
      )
      .join(" ");
  }

  get allPostsPublished() {
    return (
      this.attributes.activity_pub_published_post_count ===
      this.attributes.activity_pub_total_post_count
    );
  }

  get publishDisabled() {
    return this.status === "scheduled" || this.allPostsPublished;
  }

  get publishDescription() {
    let i18nKey;
    if (this.status === "scheduled") {
      i18nKey = "scheduled";
    } else if (this.allPostsPublished) {
      i18nKey = "published";
    } else {
      i18nKey = "unpublished";
    }
    return i18n(`topic.discourse_activity_pub.publish.description.${i18nKey}`, {
      count:
        this.attributes.activity_pub_total_post_count -
        this.attributes.activity_pub_published_post_count,
      topic_id: this.topic.id,
      actors: this.actorsString,
    });
  }

  @action
  publish() {
    ajax(`/ap/topic/publish/${this.topic.id}`, {
      type: "POST",
    })
      .then((result) => {
        if (result.success) {
          // Optimistic update
          this.apTopicTrackingState.update({
            id: this.topic.id,
            activity_pub_published_post_count:
              this.attributes.activity_pub_total_post_count,
          });
        }
      })
      .catch(popupAjaxError);
  }

  <template>
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
  </template>
}
