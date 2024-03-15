import Component from "@glimmer/component";
import { eq } from "truth-helpers";
import categoryLink from "discourse/helpers/category-link";

export default class ActivityPubActorModel extends Component {
  <template>
    <div class="activity-pub-actor-model">
      {{#if (eq @actor.model_type "category")}}
        {{categoryLink @actor.model}}
      {{/if}}
    </div>
  </template>
}
