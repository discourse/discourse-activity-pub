import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class ActivityPubActorReject extends Component {
  get title() {
    return i18n("discourse_activity_pub.actor_reject.modal_title", {
      actor: this.args.model.actor?.name,
    });
  }

  @action
  reject() {
    const model = this.args.model;
    model.reject(model.actor, model.follower);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-actor-reject-modal"
    >
      <:body>
        <div class="activity-pub-actor-reject">
          {{i18n
            "discourse_activity_pub.actor_reject.confirm"
            actor=@model.actor.name
            follower=@model.follower.handle
          }}
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.reject}}
          @label="discourse_activity_pub.actor_reject.label"
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
