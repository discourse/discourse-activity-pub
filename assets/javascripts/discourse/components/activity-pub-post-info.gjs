import Component from "@glimmer/component";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  activityPubPostStatus,
  activityPubPostStatusText,
} from "../lib/activity-pub-utilities";

export default class ActivityPubPostInfo extends Component {
  get post() {
    return this.args.post;
  }

  get showObjectType() {
    return this.args.showObjectType || false;
  }

  get status() {
    return activityPubPostStatus(this.post);
  }

  get statusText() {
    return activityPubPostStatusText(this.post, {
      showObjectType: this.showObjectType,
    });
  }

  get statusIcon() {
    if (this.status === "not_published") {
      return "far-circle-dot";
    } else {
      return this.post.activity_pub_local ? "arrow-up" : "arrow-down";
    }
  }

  get visibilityText() {
    return i18n(
      `discourse_activity_pub.visibility.description.${this.post.activity_pub_visibility}`,
      {
        object_type: this.post.activity_pub_object_type,
      }
    );
  }

  get visibilityIcon() {
    return this.post.activity_pub_visibility === "public"
      ? "earth-americas"
      : "lock";
  }

  get showVisibility() {
    return this.status !== "not_published";
  }

  get urlText() {
    return i18n("post.discourse_activity_pub.info.url", {
      object_type: this.post.activity_pub_object_type,
      actor: this.post.activity_pub_domain,
    });
  }

  get showUrl() {
    return !this.post.activity_pub_local && this.post.activity_pub_url;
  }

  get showDelivered() {
    return !!this.post.activity_pub_delivered_at;
  }

  get deliveredText() {
    let opts = {
      object_type: this.post.activity_pub_object_type,
    };
    if (this.post.activity_pub_delivered_at) {
      opts.time = moment(this.post.activity_pub_delivered_at).format(
        "h:mm a, MMM D"
      );
    }
    return i18n("post.discourse_activity_pub.object_status.delivered", opts);
  }

  <template>
    <div class="activity-pub-post-info">
      <span class="activity-pub-post-status">{{dIcon
          this.statusIcon
        }}{{this.statusText}}</span>
      {{#if this.showVisibility}}
        <span class="activity-pub-visibility">{{dIcon
            this.visibilityIcon
          }}{{this.visibilityText}}</span>
      {{/if}}
      {{#if this.showUrl}}
        <span class="activity-pub-url">
          <a
            href={{this.post.activity_pub_url}}
            target="_blank"
            rel="noopener noreferrer"
          >
            {{dIcon "up-right-from-square"}}
            {{this.urlText}}
          </a>
        </span>
      {{/if}}
      {{#if this.showDelivered}}
        <span class="activity-pub-delivered">{{dIcon
            "envelope"
          }}{{this.deliveredText}}</span>
      {{/if}}
    </div>
  </template>
}
