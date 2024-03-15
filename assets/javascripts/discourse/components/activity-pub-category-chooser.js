import CategoryChooser from "select-kit/components/category-chooser";

export default CategoryChooser.extend({
  selectKitOptions: {
    allowUncategorized: false,
  },

  categoriesByScope() {
    return this._super().filter((category) => {
      if (category.read_restricted) {
        return false;
      }
      if (this.selectKit.options.hasActor) {
        return category.activity_pub_actor_exists;
      } else {
        return !category.activity_pub_actor_exists;
      }
    });
  },
});
