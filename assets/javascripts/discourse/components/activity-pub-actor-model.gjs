import Component from "@glimmer/component";
import { equal } from "@ember/object/computed";
import categoryLink from "discourse/helpers/category-link";

export default class ActivityPubActorModel extends Component {
  @equal("args.actor.model_type", "category") isCategory;

  <template>
    <div class="activity-pub-actor-model">
      {{#if this.isCategory}}
        {{categoryLink @actor.model}}
      {{/if}}
    </div>
  </template>
}
