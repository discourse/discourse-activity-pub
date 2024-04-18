import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor, { newActor } from "../models/activity-pub-actor";

export default class AdminActivityPubActorShowRoute extends DiscourseRoute {
  model(params) {
    if (params.actor_id && params.actor_id !== newActor.id) {
      return ajax(`/admin/ap/actor/${params.actor_id}`);
    } else {
      return newActor;
    }
  }

  setupController(controller, model) {
    let props = {
      actor: ActivityPubActor.create(model),
      showForm: model.id !== newActor.id,
    };
    controller.setProperties(props);
  }
}
