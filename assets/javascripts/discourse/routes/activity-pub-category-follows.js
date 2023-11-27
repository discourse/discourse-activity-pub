import DiscourseRoute from "discourse/routes/discourse";
import { A } from "@ember/array";
import ActivityPubCategory from "../models/activity-pub-category";
import { bind } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model() {
    return Category.reloadCategoryWithPermissions(
      { slug: this.modelFor("activityPub.category").slug },
      this.store,
      this.site
    );
  },

  afterModel(model, transition) {
    const category = model;

    if (!category.can_edit) {
      this.router.replaceWith("/404");
      return;
    }

    return ActivityPubCategory.listActors(
      category.id,
      transition.to.queryParams,
      "follows"
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

  activate() {
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  },

  deactivate() {
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  },

  @bind
  handleMessage(data) {
    const model = data.model;
    const category = this.modelFor("activityPub.category");
    if (model && model.type === "category" && model.id === category.id) {
      this.refresh();
    }
  },
});
