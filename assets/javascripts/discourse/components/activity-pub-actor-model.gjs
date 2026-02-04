import Component from "@glimmer/component";
import { equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import discourseTag from "discourse/helpers/discourse-tag";

export default class ActivityPubActorModel extends Component {
  @equal("args.actor.model_type", "category") isCategory;
  @equal("args.actor.model_type", "tag") isTag;

  get rawCategoryBadgeHTML() {
    return categoryBadgeHTML(this.args.actor.model, {
      styleType: this.args.actor.model.style_type,
    });
  }

  <template>
    <div class="activity-pub-actor-model">
      {{#if this.isCategory}}
        {{htmlSafe this.rawCategoryBadgeHTML}}
      {{/if}}
      {{#if this.isTag}}
        {{discourseTag @actor.model}}
      {{/if}}
    </div>
  </template>
}
