import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  model(params) {
    return {
      category: Category.findById(params.category_id),
    };
  },

  setupController(controller, model) {
    controller.setProperties({ model });
  },
});
