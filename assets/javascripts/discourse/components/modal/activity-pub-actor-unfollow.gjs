import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class ActivityPubActorUnfollow extends Component {
  get title() {
    return i18n("discourse_activity_pub.actor_unfollow.modal_title", {
      actor: this.args.model.actor.name,
    });
  }

  @action
  unfollow() {
    const model = this.args.model;
    model.unfollow(model.actor, model.followedActor);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-actor-unfollow-modal"
    >
      <:body>
        <div class="activity-pub-actor-unfollow">
          {{i18n
            "discourse_activity_pub.actor_unfollow.confirm"
            actor=@model.actor.name
            followed_actor=@model.followedActor.handle
          }}
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.unfollow}}
          @label="discourse_activity_pub.actor_unfollow.label"
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
