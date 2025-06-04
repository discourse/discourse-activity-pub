import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAttributes from "../activity-pub-attributes";
import ActivityPubPostActions from "../activity-pub-post-actions";
import ActivityPubPostInfo from "../activity-pub-post-info";

export default class ActivityPubPostModal extends Component {
  @service modal;
  @service currentUser;

  get post() {
    return this.args.model.post;
  }

  get title() {
    return i18n("post.discourse_activity_pub.title", {
      post_number: this.post.post_number,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-topic-modal activity-pub-post-info-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "discourse_activity_pub.model.status"}}</label>
          <div class="controls">
            <ActivityPubPostInfo @post={{this.post}} />
          </div>
        </div>
        <div class="control-group">
          <label>{{i18n "discourse_activity_pub.model.attributes"}}</label>
          <div class="controls">
            <ActivityPubAttributes @post={{this.post}} />
          </div>
        </div>
        {{#if this.canAdmin}}
          <div class="control-group">
            <label>{{i18n "discourse_activity_pub.model.actions"}}</label>
            <div class="controls">
              <ActivityPubPostActions @post={{this.post}} />
            </div>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
