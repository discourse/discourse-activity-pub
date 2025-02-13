import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAttributes from "../activity-pub-attributes";
import ActivityPubPostInfo from "../activity-pub-post-info";
import ActivityPubPostAdminModal from "./activity-pub-post-admin";

export default class ActivityPubPostInfoModal extends Component {
  @service modal;
  @service currentUser;

  get post() {
    return this.args.model.post;
  }

  get title() {
    return i18n("post.discourse_activity_pub.info.title", {
      post_number: this.post.post_number,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  @action
  showAdmin() {
    this.modal.show(ActivityPubPostAdminModal, {
      model: {
        post: this.post,
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-topic-modal activity-pub-post-info-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "post.discourse_activity_pub.info.status"}}</label>
          <div class="controls">
            <ActivityPubPostInfo @post={{this.post}} />
          </div>
        </div>
        <div class="control-group">
          <label>{{i18n "post.discourse_activity_pub.info.attributes"}}</label>
          <div class="controls">
            <ActivityPubAttributes @post={{this.post}} />
          </div>
        </div>
      </:body>
      <:footer>
        {{#if this.canAdmin}}
          <DButton
            @icon="gear"
            @label="post.discourse_activity_pub.admin.label"
            @action={{this.showAdmin}}
            class="show-admin"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
