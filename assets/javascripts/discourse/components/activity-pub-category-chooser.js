import { classNames } from "@ember-decorators/component";
import CategoryChooser from "select-kit/components/category-chooser";
import { selectKitOptions } from "select-kit/components/select-kit";
import ActivityPubActor from "../models/activity-pub-actor";

@selectKitOptions({
  allowUncategorized: false,
})
@classNames("activity-pub-category-chooser")
export default class ActivityPubCategoryChooser extends CategoryChooser {
  categoriesByScope() {
    return super.categoriesByScope().filter((category) => {
      if (category.read_restricted) {
        return false;
      }
      const actor = ActivityPubActor.findByModel(category, "category");
      if (this.selectKit.options.hasActor) {
        return !!actor;
      } else {
        return !actor;
      }
    });
  }
}
