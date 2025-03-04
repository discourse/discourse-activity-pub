import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAdminInfo from "../activity-pub-admin-info";
import ActivityPubPostActions from "../activity-pub-post-actions";
import ActivityPubTopicActions from "../activity-pub-topic-actions";
import ActivityPubTopicInfo from "./activity-pub-topic-info";

export default class ActivityPubTopicAdminModal extends Component {
  @service modal;

  get title() {
    return i18n("topic.discourse_activity_pub.admin.title", {
      topic_id: this.topic.id,
    });
  }

  get topic() {
    return this.args.model.topic;
  }

  get firstPost() {
    return this.args.model.firstPost;
  }

  @action
  showInfo() {
    this.modal.show(ActivityPubTopicInfo, {
      model: {
        firstPost: this.firstPost,
        topic: this.topic,
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-topic-modal activity-pub-topic-admin-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n
              "topic.discourse_activity_pub.info.group_actors"
            }}</label>
          <div class="controls">
            <ActivityPubAdminInfo @topic={{this.topic}} @context="topic" />
          </div>
        </div>
        {{#if this.topic.activity_pub_full_topic}}
          <div class="control-group">
            <label>{{i18n "topic.discourse_activity_pub.actions.label"}}</label>
            <div class="controls">
              <ActivityPubTopicActions @topic={{this.topic}} />
            </div>
          </div>
        {{/if}}
        <div class="control-group">
          <label>{{i18n "post.discourse_activity_pub.actions.label"}}</label>
          <div class="controls">
            <ActivityPubPostActions @post={{this.firstPost}} />
          </div>
        </div>
      </:body>
      <:footer>
        <DButton
          @icon="circle-info"
          @label="topic.discourse_activity_pub.info.label"
          @action={{this.showInfo}}
          class="show-info"
        />
      </:footer>
    </DModal>
  </template>
}
