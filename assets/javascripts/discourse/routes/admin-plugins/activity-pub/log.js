import { TrackedArray } from "@ember-compat/tracked-built-ins";
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
      logs: new TrackedArray(
        (model.logs || []).map((actor) => {
          return ActivityPubLog.create(actor);
        })
      ),
    });
  }
}
