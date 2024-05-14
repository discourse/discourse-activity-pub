import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  router: service(),
  site: service(),
  store: service(),

  model(params) {
    return ActivityPubActor.find(params.actor_id);
  },

  setupController(controller, model) {
    const actor = model;
    const props = {
      actor,
      category: null,
      tag: null,
      tags: [],
    };
    if (actor.model_type === "category") {
      props.category = this.site.categories.find(
        (c) => c.id === actor.model_id
      );
    }
    if (actor.model_type === "tag") {
      const tag = this.store.createRecord("tag", {
        id: actor.model_name,
      });
      props.tag = tag;
      props.tags = [tag.id];
      props.canCreateTopicOnTag = !actor.model.staff || this.currentUser?.staff;
    }
    controller.setProperties(props);
  },

  @action
  follow(actor, followActor) {
    return ActivityPubActor.follow(actor.id, followActor.id).then((result) => {
      this.controllerFor(this.router.currentRouteName).actors.unshiftObject(
        followActor
      );
      return result;
    });
  },

  @action
  unfollow(actor, followedActor) {
    return ActivityPubActor.unfollow(actor.id, followedActor.id).then(
      (result) => {
        this.controllerFor(this.router.currentRouteName).actors.removeObject(
          followedActor
        );
        return result;
      }
    );
  },

  @action
  reject(actor, followingActor) {
    return ActivityPubActor.reject(actor.id, followingActor.id).then(
      (result) => {
        this.controllerFor(this.router.currentRouteName).actors.removeObject(
          followingActor
        );
        return result;
      }
    );
  },
});
