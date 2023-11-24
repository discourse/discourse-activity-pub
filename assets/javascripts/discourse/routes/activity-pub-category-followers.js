import DiscourseRoute from "discourse/routes/discourse";
import { A } from "@ember/array";
import ActivityPubCategory from "../models/activity-pub-category";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model() {
    return this.modelFor("activityPub.category");
  },

  afterModel(model, transition) {
    const category = model;
    return ActivityPubCategory.listActors(
      category.id,
      transition.to.queryParams,
      "followers"
    ).then((response) => this.setProperties(response));
  },

  setupController(controller, model) {
    controller.setProperties({
      model: ActivityPubCategory.create({
        category: model,
        actors: A(this.actors || []),
        loadMoreUrl: this.meta?.load_more_url,
        total: this.meta?.total,
      }),
    });
  },
});
