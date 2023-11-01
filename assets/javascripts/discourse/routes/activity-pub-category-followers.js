import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";
import { A } from "@ember/array";
import ActivityPubFollowers from "../models/activity-pub-followers";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    const category = Category.findById(params.category_id);
    return ActivityPubFollowers.load(category, params);
  },

  setupController(controller, model) {
    controller.setProperties({
      model: ActivityPubFollowers.create({
        category: model.category,
        followers: A(model.followers || []),
        loadMoreUrl: model.meta?.load_more_url,
        total: model.meta?.total,
      }),
    });
  },
});
