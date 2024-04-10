import CategoryChooser from "select-kit/components/category-chooser";
import ActivityPubActor from "../models/activity-pub-actor";

export default CategoryChooser.extend({
  classNames: ["activity-pub-category-chooser"],

  selectKitOptions: {
    allowUncategorized: false,
  },

  categoriesByScope() {
    return this._super().filter((category) => {
      if (category.read_restricted) {
        return false;
      }
      const actor = ActivityPubActor.findByModel(category.id, "category");
      if (this.selectKit.options.hasActor) {
        return !!actor;
      } else {
        return !actor;
      }
    });
  },
});
