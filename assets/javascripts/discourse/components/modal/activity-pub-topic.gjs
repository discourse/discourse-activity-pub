import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAttributes from "../activity-pub-attributes";
import ActivityPubPostActions from "../activity-pub-post-actions";
import ActivityPubPostInfo from "../activity-pub-post-info";
import ActivityPubTopicActions from "../activity-pub-topic-actions";
import ActivityPubTopicInfo from "../activity-pub-topic-info";

export default class ActivityPubTopicModal extends Component {
  @service currentUser;

  get topic() {
    return this.args.model.topic;
  }

  get firstPost() {
    return this.args.model.firstPost;
  }

  get title() {
    return i18n("topic.discourse_activity_pub.title", {
      topic_id: this.topic.id,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-topic-modal activity-pub-topic-info-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "discourse_activity_pub.model.status"}}</label>
          <div class="controls">
            <ActivityPubTopicInfo @topic={{this.topic}} />
            <ActivityPubPostInfo @post={{this.firstPost}} />
          </div>
        </div>
        <div class="control-group">
          <label>{{i18n "discourse_activity_pub.model.attributes"}}</label>
          <div class="controls">
            <ActivityPubAttributes
              @topic={{this.topic}}
              @post={{this.firstPost}}
            />
          </div>
        </div>
        {{#if this.canAdmin}}
          <div class="control-group">
            <label>{{i18n "discourse_activity_pub.model.actions"}}</label>
            <div class="controls">
              {{#if this.topic.activity_pub_full_topic}}
                <ActivityPubTopicActions @topic={{this.topic}} />
              {{/if}}
            </div>
            <div class="controls">
              <ActivityPubPostActions @post={{this.firstPost}} />
            </div>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
