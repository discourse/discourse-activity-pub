import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubObjectCopyBtn from "../activity-pub-object-copy-btn";
import ActivityPubPostInfo from "../activity-pub-post-info";
import ActivityPubPostAdmin from "./activity-pub-post-admin";

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
    this.modal.show(ActivityPubPostAdmin, {
      model: {
        post: this.post,
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-info-modal activity-pub-post-info-modal"
    >
      <:body>
        <ActivityPubPostInfo @post={{this.post}} @showObjectType={{true}} />
      </:body>
      <:footer>
        <ActivityPubObjectCopyBtn @object={{this.post}} />
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
