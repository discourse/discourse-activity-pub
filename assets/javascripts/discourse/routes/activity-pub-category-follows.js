import DiscourseRoute from "discourse/routes/discourse";
import { A } from "@ember/array";
import ActivityPubCategory from "../models/activity-pub-category";
import { bind } from "discourse-common/utils/decorators";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    const category = this.modelFor("activityPub.category").category;
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

  activate() {
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  },

  deactivate() {
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  },

  @bind
  handleMessage(data) {
    const model = data.model;
    const category = this.modelFor("activityPub.category").category;
    if (model && model.type === "category" && model.id === category.id) {
      this.refresh();
    }
  },
});
