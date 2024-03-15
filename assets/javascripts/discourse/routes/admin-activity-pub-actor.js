import { A } from "@ember/array";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
    model_type: { refreshModel: true },
  },

  model(params) {
    const queryParams = new URLSearchParams(params);
    return ajax(`/admin/ap/actor?${queryParams.toString()}`);
  },

  setupController(controller, model) {
    controller.setProperties({
      actors: A(
        (model.actors || []).map((actor) => {
          return ActivityPubActor.create(actor);
        })
      ),
    });
  },
});
