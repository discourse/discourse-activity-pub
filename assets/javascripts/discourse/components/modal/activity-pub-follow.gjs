import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ActivityPubFollowDomain from "../activity-pub-follow-domain";
import ActivityPubHandle from "../activity-pub-handle";

export default class ActivityPubFollow extends Component {
  get title() {
    const actor = this.args.model.actor;
    return i18n("discourse_activity_pub.follow.title", {
      actor: actor.name || actor.username,
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-follow-modal"
    >
      <:body>
        <div class="activity-pub-follow-controls">
          <ActivityPubFollowDomain @actor={{@model.actor}} />
          <label class="activity-pub-handle-label">
            {{i18n "discourse_activity_pub.handle.label"}}
          </label>
          <ActivityPubHandle @actor={{@model.actor}} @hideLink={{true}} />
          <div class="activity-pub-handle-description">
            {{i18n "discourse_activity_pub.handle.description"}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
