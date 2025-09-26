import { A } from "@ember/array";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubLog from "../../../models/activity-pub-log";

export default class AdminPluginsActivityPubLogRoute extends DiscourseRoute {
  queryParams = {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  };

  model(params) {
    return ActivityPubLog.list(params);
  }

  setupController(controller, model) {
    controller.setProperties({
      loadMoreUrl: model.meta.load_more_url,
      total: model.meta.total,
      logs: A(
        (model.logs || []).map((actor) => {
          return ActivityPubLog.create(actor);
        })
      ),
    });
  }
}
