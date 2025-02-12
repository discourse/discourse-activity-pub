import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubObjectCopyBtn from "../activity-pub-object-copy-btn";
import ActivityPubPostInfo from "../activity-pub-post-info";
import ActivityPubTopicInfo from "../activity-pub-topic-info";
import ActivityPubTopicAdmin from "./activity-pub-topic-admin";

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
    this.modal.show(ActivityPubTopicAdmin, {
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
      class="activity-pub-info-modal activity-pub-topic-info-modal"
    >
      <:body>
        <ActivityPubTopicInfo @topic={{this.topic}} @showObjectType={{true}} />
        <ActivityPubPostInfo
          @post={{this.firstPost}}
          @showObjectType={{true}}
        />
      </:body>

      <:footer>
        <ActivityPubObjectCopyBtn @object={{this.topic}} />
        <ActivityPubObjectCopyBtn @object={{this.firstPost}} />
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
