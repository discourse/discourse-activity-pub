import Component from "@glimmer/component";
import { equal } from "@ember/object/computed";
import categoryLink from "discourse/helpers/category-link";
import discourseTag from "discourse/helpers/discourse-tag";

export default class ActivityPubActorModel extends Component {
  @equal("args.actor.model_type", "category") isCategory;
  @equal("args.actor.model_type", "tag") isTag;

  <template>
    <div class="activity-pub-actor-model">
      {{#if this.isCategory}}
        {{categoryLink @actor.model}}
      {{/if}}
      {{#if this.isTag}}
        {{discourseTag @actor.model.name}}
      {{/if}}
    </div>
  </template>
}
