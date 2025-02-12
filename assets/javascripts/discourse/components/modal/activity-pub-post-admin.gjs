import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubAdminInfo from "../activity-pub-admin-info";
import ActivityPubPostActions from "../activity-pub-post-actions";
import ActivityPubPostInfo from "./activity-pub-post-info";

export default class ActivityPubPostAdmin extends Component {
  @service modal;

  get title() {
    return i18n("post.discourse_activity_pub.admin.title", {
      post_number: this.post.post_number,
    });
  }

  get post() {
    return this.args.model.post;
  }

  get topic() {
    return this.post.topic;
  }

  @action
  showInfo() {
    this.modal.show(ActivityPubPostInfo, {
      model: {
        post: this.post,
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-post-admin-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n
              "post.discourse_activity_pub.info.group_actors"
            }}</label>
          <div class="controls">
            <ActivityPubAdminInfo
              @post={{this.post}}
              @topic={{this.topic}}
              @context="post"
            />
          </div>
        </div>
        <div class="control-group">
          <label>{{i18n "post.discourse_activity_pub.actions.label"}}</label>
          <div class="controls">
            <ActivityPubPostActions @post={{this.post}} />
          </div>
        </div>
      </:body>
      <:footer>
        <DButton
          @icon="circle-info"
          @label="post.discourse_activity_pub.info.label"
          @action={{this.showInfo}}
          class="show-info"
        />
      </:footer>
    </DModal>
  </template>
}
