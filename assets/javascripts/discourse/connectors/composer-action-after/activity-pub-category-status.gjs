import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import ActivityPubActorStatus from "../../components/activity-pub-actor-status";
import ActivityPubActor from "../../models/activity-pub-actor";

function showStatus(attrs, component) {
  const actor = ActivityPubActor.findByModel(
    attrs.model.get("category"),
    "category"
  );
  return (
    actor &&
    actor.ready &&
    attrs.model.get("action") === "createTopic" &&
    component.site.activity_pub_publishing_enabled
  );
}

@tagName("")
export default class ActivityPubCategoryStatus extends Component {
  static shouldRender(_, context) {
    return context.site.activity_pub_enabled;
  }

  init() {
    super.init(...arguments);
    this.set("showStatus", showStatus(this, this));
    this.model.addObserver("category", () => {
      if (this._state === "destroying") {
        return;
      }
      this.set("showStatus", showStatus(this, this));
    });
  }

  <template>
    {{#if this.showStatus}}
      <ActivityPubActorStatus @model={{this.model}} @modelType="composer" />
    {{/if}}
  </template>
}
