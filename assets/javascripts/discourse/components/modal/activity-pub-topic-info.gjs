import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAttributes from "../activity-pub-attributes";
import ActivityPubPostInfo from "../activity-pub-post-info";
import ActivityPubTopicInfo from "../activity-pub-topic-info";
import ActivityPubTopicAdminModal from "./activity-pub-topic-admin";

export default class ActivityPubTopicInfoModal extends Component {
  @service modal;
  @service currentUser;

  get topic() {
    return this.args.model.topic;
  }

  get firstPost() {
    return this.args.model.firstPost;
  }

  get title() {
    return i18n("topic.discourse_activity_pub.info.title", {
      topic_id: this.topic.id,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  @action
  showAdmin() {
    this.modal.show(ActivityPubTopicAdminModal, {
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
      class="activity-pub-topic-modal activity-pub-topic-info-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "topic.discourse_activity_pub.info.status"}}</label>
          <div class="controls">
            <ActivityPubTopicInfo @topic={{this.topic}} />
            <ActivityPubPostInfo @post={{this.firstPost}} />
          </div>
        </div>
        <div class="control-group">
          <label>{{i18n "topic.discourse_activity_pub.info.attributes"}}</label>
          <div class="controls">
            <ActivityPubAttributes
              @topic={{this.topic}}
              @post={{this.firstPost}}
            />
          </div>
        </div>
      </:body>

      <:footer>
        {{#if this.canAdmin}}
          <DButton
            @icon="gear"
            @label="topic.discourse_activity_pub.admin.label"
            @action={{this.showAdmin}}
            class="show-admin"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
