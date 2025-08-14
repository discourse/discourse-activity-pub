import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../../models/activity-pub-actor";
import ActivityPubWebfinger from "../../models/activity-pub-webfinger";
import ActivityPubActor0 from "../activity-pub-actor";
import ActivityPubActorFollowBtn from "../activity-pub-actor-follow-btn";

export default class ActivityPubFollowRemote extends Component {
  @tracked verifying = false;
  @tracked error = null;
  @tracked followActor;

  get title() {
    return i18n("discourse_activity_pub.actor_follow.title", {
      actor: this.args.model.actor.name,
    });
  }

  get footerClass() {
    let result = "activity-pub-actor-follow-find-footer";
    if (this.error) {
      result += " error";
    }
    return result;
  }

  get actorClass() {
    let result = "activity-pub-actor-follow-actor-container";
    if (!this.followActor) {
      result += " no-actor";
    }
    return result;
  }

  get notFound() {
    return this.followActor === false;
  }

  @action
  onKeyup(e) {
    this.error = null;

    if (e.key === "Enter") {
      this.find();
    } else {
      this.followActor = null;
    }
  }

  @action
  follow(actor, followActor) {
    return this.args.model.follow(actor, followActor).then(() => {
      this.args.closeModal();
    });
  }

  @action
  async find() {
    const handle = this.handle;

    if (!handle) {
      return;
    }

    this.validating = true;
    const validated = await ActivityPubWebfinger.validateHandle(handle);
    this.validating = false;

    if (validated) {
      this.finding = true;
      this.followActor = await ActivityPubActor.findByHandle(
        this.args.model.actor.id,
        handle
      );
      this.finding = false;
    } else {
      this.error = i18n("discourse_activity_pub.actor_follow.find.invalid");
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="activity-pub-actor-follow-modal"
    >
      <:body>
        <div class="activity-pub-actor-follow">
          <div class="activity-pub-actor-follow-controls">
            <label>{{i18n
                "discourse_activity_pub.actor_follow.find.label"
              }}</label>
            <div class="activity-pub-actor-follow-find">
              <Input
                id="activity_pub_actor_follow_find_input"
                @value={{this.handle}}
                {{on "keyup" this.onKeyup}}
              />
              <DButton
                @icon="magnifying-glass"
                @action={{this.find}}
                @label="discourse_activity_pub.actor_follow.find.btn_label"
                @title="discourse_activity_pub.actor_follow.find.btn_title"
                @disabled={{this.validating}}
                id="activity_pub_actor_follow_find_button"
              />
            </div>
            <div class={{this.footerClass}}>
              {{#if this.error}}
                {{this.error}}
              {{else if this.validating}}
                {{i18n "discourse_activity_pub.actor_follow.find.validating"}}
              {{else}}
                {{i18n "discourse_activity_pub.actor_follow.find.description"}}
              {{/if}}
            </div>
          </div>
          <div class={{this.actorClass}}>
            {{#if this.followActor}}
              <div class="activity-pub-actor-follow-actor">
                <ActivityPubActor0 @actor={{this.followActor}} />
                <ActivityPubActorFollowBtn
                  @actor={{@model.actor}}
                  @followActor={{this.followActor}}
                  @follow={{this.follow}}
                />
              </div>
            {{else if this.finding}}
              {{loadingSpinner size="small"}}
            {{else if this.notFound}}
              {{i18n
                "discourse_activity_pub.actor_follow.find.not_found"
                handle=this.handle
              }}
            {{/if}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
