import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";
import { A } from "@ember/array";
import ActivityPubCategory from "../models/activity-pub-category";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    const categoryId = this.paramsFor("activityPub.category").category_id;
    const category = Category.findById(categoryId);
    return ActivityPubCategory.listActors(category, params, "follows");
  },

  setupController(controller, model) {
    controller.setProperties({
      model: ActivityPubCategory.create({
        category: model.category,
        actors: A(model.actors || []),
        loadMoreUrl: model.meta?.load_more_url,
        total: model.meta?.total,
      }),
    });
  },
});
