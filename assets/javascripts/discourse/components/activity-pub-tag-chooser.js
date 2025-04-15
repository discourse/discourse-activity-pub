import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { selectKitOptions } from "select-kit/components/select-kit";
import TagChooser from "select-kit/components/tag-chooser";

@selectKitOptions({
  allowUncategorized: false,
  filterPlaceholder: "admin.discourse_activity_pub.actor.tag.filter",
  none: "admin.discourse_activity_pub.actor.tag.none",
  allowAny: false,
  maximum: 1,
})
@classNames("activity-pub-tag-chooser")
export default class ActivityPubTagChooser extends TagChooser {
  @service site;

  get blockedTags() {
    const tagActors = this.get("site.activity_pub_actors.tag") || [];
    return tagActors
      .filter((actor) => actor.model_name)
      .map((actor) => {
        return actor.model_name;
      });
  }
}
