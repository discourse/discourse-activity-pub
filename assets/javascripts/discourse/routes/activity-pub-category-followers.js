import DiscourseRoute from "discourse/routes/discourse";
import { A } from "@ember/array";
import ActivityPubCategory from "../models/activity-pub-category";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    const category = this.modelFor("activityPub.category").category;
    return ActivityPubCategory.listActors(category, params, "followers");
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
