import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  model(params) {
    if (params.actor_id && params.actor_id !== "new") {
      return ajax(`/admin/ap/actor/${params.actor_id}`);
    } else {
      return {
        id: "new",
      };
    }
  },

  setupController(controller, model) {
    let props = {
      actor: ActivityPubActor.create(model),
      showForm: model.id !== "new",
    };
    controller.setProperties(props);
  },
});
