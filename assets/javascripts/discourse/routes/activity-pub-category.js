import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    return Category.findById(params.category_id);
  },

  setupController(controller, model) {
    controller.setProperties({ model });
  },

  @action
  follow(actor, followActor) {
    return ActivityPubActor.follow(actor.id, followActor.id).then((result) => {
      this.controllerFor(
        this.router.currentRouteName
      ).model.actors.unshiftObject(followActor);
      return result;
    });
  },

  @action
  unfollow(actor, followedActor) {
    return ActivityPubActor.unfollow(actor.id, followedActor.id).then(
      (result) => {
        this.controllerFor(
          this.router.currentRouteName
        ).model.actors.removeObject(followedActor);
        return result;
      }
    );
  },

  @action
  reject(actor, followingActor) {
    return ActivityPubActor.reject(actor.id, followingActor.id).then(
      (result) => {
        this.controllerFor(
          this.router.currentRouteName
        ).model.actors.removeObject(followingActor);
        return result;
      }
    );
  },
});
